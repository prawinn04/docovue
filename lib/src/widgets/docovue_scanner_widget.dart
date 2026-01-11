import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:async';
import 'dart:io';

import '../models/document_type.dart';
import '../models/extraction_result.dart';
import '../models/scanner_config.dart';
import '../docovue_scanner.dart';

/// A reusable widget that provides a complete document scanning interface.
/// 
/// This widget includes:
/// - Live camera preview
/// - Document frame overlay with guides
/// - Auto-capture when document is detected and stable
/// - Manual capture button
/// - Flash/torch toggle
/// - Gallery import option
/// - Loading states and error handling
/// 
/// Example usage:
/// ```dart
/// DocovueScannerWidget(
///   allowedTypes: const {
///     DocovueDocumentType.aadhaar,
///     DocovueDocumentType.pan,
///   },
///   config: const DocovueScannerConfig(),
///   onResult: (result) {
///     // Handle scan result
///   },
/// )
/// ```
class DocovueScannerWidget extends StatefulWidget {
  const DocovueScannerWidget({
    super.key,
    required this.allowedTypes,
    required this.onResult,
    this.config = const DocovueScannerConfig(),
    this.onError,
    this.customOverlay,
  });

  /// Set of allowed document types for scanning
  final Set<DocovueDocumentType> allowedTypes;

  /// Callback called when scanning completes (success, unclear, or error)
  final void Function(DocovueScanResult result) onResult;

  /// Scanner configuration
  final DocovueScannerConfig config;

  /// Optional callback for handling errors during setup
  final void Function(String error)? onError;

  /// Optional custom overlay widget to display over the camera preview
  final Widget? customOverlay;

  @override
  State<DocovueScannerWidget> createState() => _DocovueScannerWidgetState();
}

class _DocovueScannerWidgetState extends State<DocovueScannerWidget>
    with WidgetsBindingObserver {
  CameraController? _cameraController;
  List<CameraDescription>? _cameras;
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _flashEnabled = false;
  String? _errorMessage;
  bool _showConsentDialogFlag = false;
  CameraLensDirection _currentLensDirection = CameraLensDirection.back; // Track current camera
  
  // Edge detection and auto-capture state
  bool _documentDetected = false;
  bool _documentStable = false;
  int _stableFrameCount = 0;
  String _feedbackMessage = 'Position document within the frame';
  Color _boundingBoxColor = Colors.white;
  
  // Liveness/anti-spoofing state
  bool _livenessCheckFailed = false;
  String? _livenessError;
  
  // Auto-detection timer
  Timer? _detectionTimer;
  bool _autoCaptureLocked = false;
  int _consecutiveFailures = 0; // Track detection failures
  
  // Constants for auto-capture logic - OPTIMIZED FOR BEST AUTO-DETECTION
  static const int _requiredStableFrames = 4; // 2 seconds - fast but reliable
  static const Duration _detectionInterval = Duration(milliseconds: 500);
  static const int _maxConsecutiveFailures = 8; // Quick reset

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeCamera();
  }

  @override
  void dispose() {
    _detectionTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _cameraController;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  Future<void> _initializeCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras == null || _cameras!.isEmpty) {
        setState(() {
          _errorMessage = 'No cameras available';
        });
        widget.onError?.call('No cameras available');
        return;
      }

      // Select camera based on current lens direction
      final selectedCamera = _cameras!.firstWhere(
        (camera) => camera.lensDirection == _currentLensDirection,
        orElse: () => _cameras!.first,
      );

      _cameraController = CameraController(
        selectedCamera,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await _cameraController!.initialize();

      if (mounted) {
        setState(() {
          _isInitialized = true;
          _errorMessage = null;
        });
        
        // Start auto-detection if enabled
        if (widget.config.autoCapture) {
          _startAutoDetection();
        }
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to initialize camera: $e';
      });
      widget.onError?.call('Failed to initialize camera: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras == null || _cameras!.length < 2) {
      debugPrint('Camera switching not available');
      return;
    }

    setState(() {
      _isInitialized = false;
    });

    // Stop auto-detection during camera switch
    _stopAutoDetection();

    // Dispose current controller
    await _cameraController?.dispose();

    // Switch lens direction
    _currentLensDirection = _currentLensDirection == CameraLensDirection.back
        ? CameraLensDirection.front
        : CameraLensDirection.back;

    // Reinitialize with new camera
    await _initializeCamera();
  }

  Future<void> _toggleFlash() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      final newFlashMode = _flashEnabled ? FlashMode.off : FlashMode.torch;
      await _cameraController!.setFlashMode(newFlashMode);
      setState(() {
        _flashEnabled = !_flashEnabled;
      });
    } catch (e) {
      // Flash might not be available on this device
      debugPrint('Flash toggle failed: $e');
    }
  }

  void _startAutoDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = Timer.periodic(_detectionInterval, (_) {
      if (mounted && !_isScanning && !_autoCaptureLocked) {
        _performDocumentDetection();
      }
    });
  }

  void _stopAutoDetection() {
    _detectionTimer?.cancel();
    _detectionTimer = null;
  }

  Future<void> _performDocumentDetection() async {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    try {
      // Capture a temporary frame for analysis
      final image = await _cameraController!.takePicture();
      
      // Perform edge detection (check if document is in frame)
      final edgeResult = await DocovueScanner.detectDocumentEdges(image.path);
      
      final detected = edgeResult['detected'] == true;
      final coverage = (edgeResult['coverage'] as num?)?.toDouble() ?? 0.0;
      
      // More lenient coverage threshold for better auto-detection
      if (detected && coverage > 0.4) {
        // Document detected with acceptable coverage!
        _consecutiveFailures = 0; // Reset failure counter
        
        setState(() {
          _documentDetected = true;
          _boundingBoxColor = Colors.orange;
          _feedbackMessage = 'Hold steady... ${_stableFrameCount + 1}/$_requiredStableFrames';
        });
        
        // Increment stable frame count
        _stableFrameCount++;
        
        if (_stableFrameCount >= _requiredStableFrames) {
          // Document is stable - ready for capture
          setState(() {
            _documentStable = true;
            _boundingBoxColor = Colors.green;
            _feedbackMessage = 'Perfect! Capturing...';
          });
          
          // Trigger auto-capture
          _autoCaptureLocked = true;
          await _autoCapture(image.path);
          return; // Exit early - capture is in progress
        }
      } else {
        // Document not detected or coverage too low
        _consecutiveFailures++;
        
        // Only reset UI if we had a detection before
        if (_documentDetected || _consecutiveFailures > _maxConsecutiveFailures) {
          setState(() {
            _documentDetected = false;
            _documentStable = false;
            _stableFrameCount = 0;
            _boundingBoxColor = Colors.white;
            _feedbackMessage = coverage < 0.3 
                ? 'Move closer to document'
                : 'Position document in center';
            if (_consecutiveFailures > _maxConsecutiveFailures) {
              _consecutiveFailures = 0;
            }
          });
        }
      }
      
      // Clean up temporary image
      try {
        await File(image.path).delete();
      } catch (_) {}
      
    } catch (e) {
      debugPrint('Document detection error: $e');
      _consecutiveFailures++;
    }
  }

  Future<void> _autoCapture(String imagePath) async {
    if (_isScanning) return;
    
    _stopAutoDetection(); // Pause detection during processing
    
    setState(() {
      _isScanning = true;
    });

    try {
      // Show consent dialog if required and not shown yet
      if (widget.config.showConsentDialog && !_showConsentDialogFlag) {
        final consent = await _showConsentDialog();
        if (!consent) {
          widget.onResult(const DocovueScanError(error: UserCancelled()));
          return;
        }
        setState(() {
          _showConsentDialogFlag = true;
        });
      }

      // Perform liveness detection if enabled
      if (widget.config.verifyOriginal) {
        setState(() {
          _feedbackMessage = 'Verifying authenticity...';
        });
        
        final livenessResult = await DocovueScanner.verifyLiveness(imagePath);
        
        if (livenessResult['isOriginal'] != true) {
          // Liveness check failed - show error overlay
          setState(() {
            _livenessCheckFailed = true;
            _livenessError = livenessResult['reason'] as String? ?? 
                'Document may not be original. Please use a physical document.';
            _boundingBoxColor = Colors.red;
            _feedbackMessage = 'Original ID Required';
          });
          
          // Reset after showing error
          await Future<void>.delayed(const Duration(seconds: 3));
          setState(() {
            _livenessCheckFailed = false;
            _livenessError = null;
            _documentDetected = false;
            _documentStable = false;
            _stableFrameCount = 0;
            _boundingBoxColor = Colors.white;
            _feedbackMessage = 'Position document within the frame';
            _autoCaptureLocked = false;
          });
          
          // Resume detection
          if (widget.config.autoCapture) {
            _startAutoDetection();
          }
          return;
        }
      }

      // Process with DocovueScanner
      final result = await DocovueScanner.scanDocumentFromFile(
        imagePath: imagePath,
        allowedTypes: widget.allowedTypes,
        config: widget.config,
      );
      
      widget.onResult(result);

    } catch (e) {
      widget.onResult(DocovueScanError(error: GenericError(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
          _autoCaptureLocked = false;
          _documentDetected = false;
          _documentStable = false;
          _stableFrameCount = 0;
          _boundingBoxColor = Colors.white;
          _feedbackMessage = 'Position document within the frame';
        });
      }
    }
  }

  Future<void> _captureAndScan() async {
    if (_cameraController == null || 
        !_cameraController!.value.isInitialized || 
        _isScanning) {
      return;
    }

    setState(() {
      _isScanning = true;
    });

    try {
      // Show consent dialog if required and not shown yet
      if (widget.config.showConsentDialog && !_showConsentDialogFlag) {
        final consent = await _showConsentDialog();
        if (!consent) {
          widget.onResult(const DocovueScanError(error: UserCancelled()));
          return;
        }
        setState(() {
          _showConsentDialogFlag = true;
        });
      }

      // Capture image
      final image = await _cameraController!.takePicture();
      
      // Process with real DocovueScanner pipeline
      final result = await DocovueScanner.scanDocumentFromFile(
        imagePath: image.path,
        allowedTypes: widget.allowedTypes,
        config: widget.config,
      );
      
      widget.onResult(result);

    } catch (e) {
      widget.onResult(DocovueScanError(error: GenericError(e.toString())));
    } finally {
      if (mounted) {
        setState(() {
          _isScanning = false;
        });
      }
    }
  }

  Future<bool> _showConsentDialog() async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(widget.config.consentDialogTitle ?? 
                   DocovueScannerConfig.defaultConsentTitle),
        content: Text(widget.config.consentDialogMessage ?? 
                     DocovueScannerConfig.defaultConsentMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Decline'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Accept'),
          ),
        ],
      ),
    ) ?? false;
  }



  @override
  Widget build(BuildContext context) {
    if (_errorMessage != null) {
      return _buildErrorWidget();
    }

    if (!_isInitialized || _cameraController == null) {
      return _buildLoadingWidget();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Camera preview
          Positioned.fill(
            child: CameraPreview(_cameraController!),
          ),

          // Custom overlay or default document frame
          if (widget.customOverlay != null)
            widget.customOverlay!
          else
            _buildDefaultOverlay(),

          // Loading overlay
          if (_isScanning)
            _buildScanningOverlay(),

          // Controls
          _buildControls(),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              color: Colors.white,
              size: 64,
            ),
            const SizedBox(height: 16),
            Text(
              'Camera Error',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _initializeCamera,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingWidget() {
    return const Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Initializing camera...',
              style: TextStyle(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDefaultOverlay() {
    return Stack(
      children: [
        // Semi-transparent overlay with cutout
        Container(
          color: Colors.black.withValues(alpha: 0.5),
        ),

        // Document frame with dynamic color based on detection state
        Center(
          child: Container(
            width: MediaQuery.of(context).size.width * 0.85,
            height: MediaQuery.of(context).size.height * 0.55,
            decoration: BoxDecoration(
              border: Border.all(
                color: _boundingBoxColor,
                width: _documentDetected ? 3 : 2,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Stack(
              children: [
                // Corner guides that animate based on detection
                ...List.generate(4, (index) => _buildCornerGuide(index)),
                
                // Top feedback message
                Positioned(
                  top: 16,
                  left: 16,
                  right: 16,
                  child: _buildFeedbackMessage(),
                ),

                // Center instruction when no document detected
                if (!_documentDetected && _livenessError == null)
                  Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.7),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.credit_card,
                            color: Colors.white,
                            size: 48,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _getInstructionText(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  ),

                // Liveness error overlay
                if (_livenessCheckFailed && _livenessError != null)
                  _buildLivenessErrorOverlay(),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFeedbackMessage() {
    IconData icon;
    Color bgColor;
    Color iconColor;

    if (_livenessCheckFailed) {
      icon = Icons.error_outline;
      bgColor = Colors.red.shade700;
      iconColor = Colors.white;
    } else if (_documentStable) {
      icon = Icons.check_circle;
      bgColor = Colors.green.shade600;
      iconColor = Colors.white;
    } else if (_documentDetected) {
      icon = Icons.center_focus_strong;
      bgColor = Colors.orange.shade700;
      iconColor = Colors.white;
    } else {
      icon = Icons.document_scanner;
      bgColor = Colors.white.withValues(alpha: 0.9);
      iconColor = Colors.black87;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: iconColor, size: 20),
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              _feedbackMessage,
              style: TextStyle(
                color: iconColor,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLivenessErrorOverlay() {
    return Container(
      margin: const EdgeInsets.all(20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.red.shade700,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            color: Colors.white,
            size: 64,
          ),
          const SizedBox(height: 16),
          const Text(
            'Original ID Required',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            _livenessError ?? 'Please present the physical document',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _livenessCheckFailed = false;
                _livenessError = null;
                _feedbackMessage = 'Position document within the frame';
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.red.shade700,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Try Again',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCornerGuide(int index) {
    const size = 28.0;
    const thickness = 4.0;
    final color = _documentStable 
        ? Colors.green 
        : _documentDetected 
            ? Colors.orange 
            : _boundingBoxColor;

    Widget guide;
    switch (index) {
      case 0: // Top-left
        guide = Positioned(
          top: -thickness / 2,
          left: -thickness / 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: thickness),
                left: BorderSide(color: color, width: thickness),
              ),
            ),
          ),
        );
        break;
      case 1: // Top-right
        guide = Positioned(
          top: -thickness / 2,
          right: -thickness / 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(color: color, width: thickness),
                right: BorderSide(color: color, width: thickness),
              ),
            ),
          ),
        );
        break;
      case 2: // Bottom-left
        guide = Positioned(
          bottom: -thickness / 2,
          left: -thickness / 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: thickness),
                left: BorderSide(color: color, width: thickness),
              ),
            ),
          ),
        );
        break;
      case 3: // Bottom-right
        guide = Positioned(
          bottom: -thickness / 2,
          right: -thickness / 2,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: size,
            height: size,
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(color: color, width: thickness),
                right: BorderSide(color: color, width: thickness),
              ),
            ),
          ),
        );
        break;
      default:
        guide = const SizedBox.shrink();
    }

    return guide;
  }

  String _getInstructionText() {
    if (widget.allowedTypes.length == 1) {
      final type = widget.allowedTypes.first;
      return 'Position your ${type.displayName.toLowerCase()} within the frame';
    } else {
      return 'Position your document within the frame';
    }
  }

  Widget _buildScanningOverlay() {
    return Container(
      color: Colors.black.withValues(alpha: 0.7),
      child: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 16),
            Text(
              'Analyzing document...',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildControls() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              Colors.black.withValues(alpha: 0.8)
            ],
          ),
        ),
        child: SafeArea(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // Camera switch button
              if (_cameras != null && _cameras!.length > 1)
                _buildControlButton(
                  icon: _currentLensDirection == CameraLensDirection.back
                      ? Icons.camera_front
                      : Icons.camera_rear,
                  onPressed: _isScanning ? null : _switchCamera,
                ),

              // Auto-capture indicator (replaces manual capture button)
              if (widget.config.autoCapture)
                _buildAutoModeIndicator()
              else
                _buildCaptureButton(), // Manual capture if auto is off

              // Flash toggle button
              if (widget.config.enableFlash)
                _buildControlButton(
                  icon: _flashEnabled ? Icons.flash_on : Icons.flash_off,
                  onPressed: _isScanning ? null : _toggleFlash,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(
          icon,
          color: Colors.white,
          size: 24,
        ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      onTap: _isScanning ? null : _captureAndScan,
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          color: _isScanning ? Colors.grey : Colors.white,
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white,
            width: 4,
          ),
        ),
        child: _isScanning
            ? const Center(
                child: SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.black),
                  ),
                ),
              )
            : const Icon(
                Icons.camera_alt,
                color: Colors.black,
                size: 32,
              ),
      ),
    );
  }

  Widget _buildAutoModeIndicator() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: _documentStable 
            ? Colors.green.withValues(alpha: 0.9)
            : _documentDetected
                ? Colors.orange.withValues(alpha: 0.9)
                : Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _isScanning
                ? Icons.hourglass_empty
                : _documentStable
                    ? Icons.check_circle
                    : _documentDetected
                        ? Icons.camera_alt
                        : Icons.auto_awesome,
            color: _documentStable || _documentDetected ? Colors.white : Colors.black,
            size: 20,
          ),
          const SizedBox(width: 8),
          Text(
            _isScanning
                ? 'Processing...'
                : _documentStable
                    ? 'Capturing!'
                    : _documentDetected
                        ? '${_stableFrameCount}/$_requiredStableFrames'
                        : 'AUTO',
            style: TextStyle(
              color: _documentStable || _documentDetected ? Colors.white : Colors.black,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}