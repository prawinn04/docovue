import 'package:meta/meta.dart';

/// Configuration options for the document scanner.
@immutable
class DocovueScannerConfig {
  const DocovueScannerConfig({
    this.showConsentDialog = true,
    this.maskSensitiveDataInLogs = true,
    this.debugMode = false,
    this.autoCapture = true,
    this.verifyOriginal = false,
    this.confidenceThreshold = 0.8,
    this.allowedLanguages = const ['en'],
    this.captureTimeout = const Duration(seconds: 10),
    this.maxRetries = 3,
    this.enableFlash = true,
    this.enableGalleryImport = true,
    this.consentDialogTitle,
    this.consentDialogMessage,
    this.customValidators = const {},
  });

  /// Whether to show a consent dialog before scanning (GDPR compliance)
  final bool showConsentDialog;

  /// Whether to mask sensitive data in logs (PCI-DSS, PHI compliance)
  final bool maskSensitiveDataInLogs;

  /// Whether to enable debug mode with additional logging
  final bool debugMode;

  /// Whether to automatically capture when document is detected and stable
  final bool autoCapture;

  /// Whether to verify document is original (anti-spoofing/liveness detection)
  /// When true, the scanner will analyze the captured frame for signs of
  /// re-presentation attacks (e.g., photo of a photo, screen display).
  /// Only physical, original documents will pass verification.
  final bool verifyOriginal;

  /// Minimum confidence threshold for accepting extraction results (0.0 to 1.0)
  final double confidenceThreshold;

  /// List of allowed language codes for OCR (e.g., ['en', 'hi'])
  final List<String> allowedLanguages;

  /// Maximum time to wait for document capture
  final Duration captureTimeout;

  /// Maximum number of retry attempts for failed captures
  final int maxRetries;

  /// Whether to enable flash/torch toggle
  final bool enableFlash;

  /// Whether to enable importing images from gallery
  final bool enableGalleryImport;

  /// Custom title for the consent dialog (null uses default)
  final String? consentDialogTitle;

  /// Custom message for the consent dialog (null uses default)
  final String? consentDialogMessage;

  /// Custom validators for specific document types
  final Map<String, bool Function(String)> customValidators;

  /// Default consent dialog title
  static const String defaultConsentTitle = 'Document Scanning Consent';

  /// Default consent dialog message
  static const String defaultConsentMessage = 
      'This app will scan and process your document using on-device OCR technology. '
      'No data will be sent to external servers. The extracted information will be '
      'used only for the intended purpose and will not be stored permanently by this scanner. '
      'Do you consent to proceed?';

  /// Creates a copy of this config with updated properties
  DocovueScannerConfig copyWith({
    bool? showConsentDialog,
    bool? maskSensitiveDataInLogs,
    bool? debugMode,
    bool? autoCapture,
    bool? verifyOriginal,
    double? confidenceThreshold,
    List<String>? allowedLanguages,
    Duration? captureTimeout,
    int? maxRetries,
    bool? enableFlash,
    bool? enableGalleryImport,
    String? consentDialogTitle,
    String? consentDialogMessage,
    Map<String, bool Function(String)>? customValidators,
  }) {
    return DocovueScannerConfig(
      showConsentDialog: showConsentDialog ?? this.showConsentDialog,
      maskSensitiveDataInLogs: maskSensitiveDataInLogs ?? this.maskSensitiveDataInLogs,
      debugMode: debugMode ?? this.debugMode,
      autoCapture: autoCapture ?? this.autoCapture,
      verifyOriginal: verifyOriginal ?? this.verifyOriginal,
      confidenceThreshold: confidenceThreshold ?? this.confidenceThreshold,
      allowedLanguages: allowedLanguages ?? this.allowedLanguages,
      captureTimeout: captureTimeout ?? this.captureTimeout,
      maxRetries: maxRetries ?? this.maxRetries,
      enableFlash: enableFlash ?? this.enableFlash,
      enableGalleryImport: enableGalleryImport ?? this.enableGalleryImport,
      consentDialogTitle: consentDialogTitle ?? this.consentDialogTitle,
      consentDialogMessage: consentDialogMessage ?? this.consentDialogMessage,
      customValidators: customValidators ?? this.customValidators,
    );
  }

  /// Returns a config optimized for high-security environments
  factory DocovueScannerConfig.highSecurity() {
    return const DocovueScannerConfig(
      showConsentDialog: true,
      maskSensitiveDataInLogs: true,
      debugMode: false,
      verifyOriginal: true,
      confidenceThreshold: 0.9,
      maxRetries: 1,
      enableGalleryImport: false,
    );
  }

  /// Returns a config optimized for development and testing
  factory DocovueScannerConfig.development() {
    return const DocovueScannerConfig(
      showConsentDialog: false,
      maskSensitiveDataInLogs: false,
      debugMode: true,
      confidenceThreshold: 0.6,
      maxRetries: 5,
      captureTimeout: Duration(seconds: 30),
    );
  }

  /// Returns a config optimized for healthcare/PHI environments
  factory DocovueScannerConfig.healthcare() {
    return const DocovueScannerConfig(
      showConsentDialog: true,
      maskSensitiveDataInLogs: true,
      debugMode: false,
      confidenceThreshold: 0.85,
      maxRetries: 2,
      consentDialogTitle: 'Medical Document Scanning Consent',
      consentDialogMessage: 
          'This app will scan your medical document using secure on-device processing. '
          'No health information will be transmitted or stored externally. '
          'The extracted data will be used only for the intended medical purpose. '
          'Do you consent to proceed with scanning your medical document?',
    );
  }

  /// Returns a config optimized for financial/PCI environments
  factory DocovueScannerConfig.financial() {
    return const DocovueScannerConfig(
      showConsentDialog: true,
      maskSensitiveDataInLogs: true,
      debugMode: false,
      verifyOriginal: true,
      confidenceThreshold: 0.95,
      maxRetries: 1,
      consentDialogTitle: 'Financial Document Scanning Consent',
      consentDialogMessage: 
          'This app will scan your financial document using secure on-device processing. '
          'No financial information will be transmitted to external servers. '
          'Card details will be extracted for convenience only and must be handled '
          'according to PCI-DSS requirements by your application. '
          'Do you consent to proceed?',
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocovueScannerConfig &&
          runtimeType == other.runtimeType &&
          showConsentDialog == other.showConsentDialog &&
          maskSensitiveDataInLogs == other.maskSensitiveDataInLogs &&
          debugMode == other.debugMode &&
          autoCapture == other.autoCapture &&
          verifyOriginal == other.verifyOriginal &&
          confidenceThreshold == other.confidenceThreshold &&
          allowedLanguages == other.allowedLanguages &&
          captureTimeout == other.captureTimeout &&
          maxRetries == other.maxRetries &&
          enableFlash == other.enableFlash &&
          enableGalleryImport == other.enableGalleryImport &&
          consentDialogTitle == other.consentDialogTitle &&
          consentDialogMessage == other.consentDialogMessage;

  @override
  int get hashCode => Object.hash(
        showConsentDialog,
        maskSensitiveDataInLogs,
        debugMode,
        autoCapture,
        verifyOriginal,
        confidenceThreshold,
        allowedLanguages,
        captureTimeout,
        maxRetries,
        enableFlash,
        enableGalleryImport,
        consentDialogTitle,
        consentDialogMessage,
      );

  @override
  String toString() => 'DocovueScannerConfig('
      'showConsentDialog: $showConsentDialog, '
      'maskSensitiveDataInLogs: $maskSensitiveDataInLogs, '
      'debugMode: $debugMode, '
      'autoCapture: $autoCapture, '
      'verifyOriginal: $verifyOriginal, '
      'confidenceThreshold: $confidenceThreshold, '
      'allowedLanguages: $allowedLanguages, '
      'captureTimeout: $captureTimeout, '
      'maxRetries: $maxRetries, '
      'enableFlash: $enableFlash, '
      'enableGalleryImport: $enableGalleryImport'
      ')';
}