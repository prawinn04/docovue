import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'models/document_type.dart';
import 'models/extraction_result.dart';
import 'models/text_block.dart';
import 'models/scanner_config.dart';
import 'utils/validators.dart';
import 'utils/parsing_utils.dart';

/// Main facade for document scanning and OCR operations.
/// 
/// This class provides both high-level and low-level APIs for document scanning,
/// OCR text extraction, and structured data extraction.
class DocovueScanner {
  static const MethodChannel _channel = MethodChannel('docovue');

  /// High-level API: Scan a document with automatic type detection and data extraction.
  /// 
  /// This is the main entry point for most applications. It handles:
  /// - Camera permission requests
  /// - Document capture (camera or gallery)
  /// - OCR text extraction
  /// - Document type classification
  /// - Structured data extraction
  /// - Privacy compliance (consent dialogs, data masking)
  /// 
  /// Example:
  /// ```dart
  /// final result = await DocovueScanner.scanDocument(
  ///   context: context,
  ///   allowedTypes: const {
  ///     DocovueDocumentType.aadhaar,
  ///     DocovueDocumentType.pan,
  ///     DocovueDocumentType.creditCard,
  ///   },
  ///   config: const DocovueScannerConfig(
  ///     showConsentDialog: true,
  ///     maskSensitiveDataInLogs: true,
  ///   ),
  /// );
  /// ```
  static Future<DocovueScanResult> scanDocument({
    required BuildContext context,
    required Set<DocovueDocumentType> allowedTypes,
    DocovueScannerConfig config = const DocovueScannerConfig(),
  }) async {
    try {
      // Show consent dialog if required
      if (config.showConsentDialog) {
        final consent = await _showConsentDialog(context, config);
        if (!consent) {
          return const DocovueScanError(error: UserCancelled());
        }
      }

      // Extract text from image (camera or gallery)
      final textBlocks = await _captureAndExtractText(config);
      return await _processScanPipeline(textBlocks, allowedTypes, config);

    } on PlatformException catch (e) {
      return DocovueScanError(error: _mapPlatformException(e));
    } catch (e) {
      return DocovueScanError(error: GenericError(e.toString()));
    }
  }

  /// High-level API: Scan a document from an existing image file path.
  ///
  /// This is useful when you already have an image (e.g. from image_picker)
  /// and want to run the full Docovue pipeline (OCR + classification + extraction)
  /// on that file.
  static Future<DocovueScanResult> scanDocumentFromFile({
    required String imagePath,
    required Set<DocovueDocumentType> allowedTypes,
    DocovueScannerConfig config = const DocovueScannerConfig(),
  }) async {
    try {
      final textBlocks = await extractTextFromImage(
        DocovueImageSource.file,
        languages: config.allowedLanguages,
        imagePath: imagePath,
      );

      return await _processScanPipeline(textBlocks, allowedTypes, config);
    } on PlatformException catch (e) {
      return DocovueScanError(error: _mapPlatformException(e));
    } catch (e) {
      return DocovueScanError(error: GenericError(e.toString()));
    }
  }

  /// Internal helper to run classification + extraction + confidence checks
  /// on a list of OCR text blocks.
  static Future<DocovueScanResult> _processScanPipeline(
    List<DocovueTextBlock> textBlocks,
    Set<DocovueDocumentType> allowedTypes,
    DocovueScannerConfig config,
  ) async {
    if (textBlocks.isEmpty) {
      return const DocovueScanError(error: OcrProcessingFailed('No text detected'));
    }

    // Classify document type
    final detectedType = await classifyDocument(
      textBlocks,
      allowedTypes: allowedTypes,
    );

    if (detectedType == null) {
      // Return unclear result with raw text for manual review
      final rawText = textBlocks.map((b) => b.text).join(' ');
      final avgConfidence = textBlocks
              .map((b) => b.confidence)
              .reduce((a, b) => a + b) /
          textBlocks.length;

      if (avgConfidence < config.confidenceThreshold) {
        return DocovueScanUnclear(rawText: rawText, confidence: avgConfidence);
      }
    }

    // Extract structured data
    final document = await extractDocumentData(
      detectedType ?? DocovueDocumentType.generic,
      textBlocks,
      config: config,
    );

    if (document == null) {
      final rawText = textBlocks.map((b) => b.text).join(' ');
      final avgConfidence = textBlocks
              .map((b) => b.confidence)
              .reduce((a, b) => a + b) /
          textBlocks.length;
      return DocovueScanUnclear(rawText: rawText, confidence: avgConfidence);
    }

    // Check if extraction meets confidence threshold
    if (document.overallConfidence < config.confidenceThreshold) {
      final rawText = textBlocks.map((b) => b.text).join(' ');
      return DocovueScanUnclear(
        rawText: rawText,
        confidence: document.overallConfidence,
      );
    }

    return DocovueScanSuccess(document: document);
  }

  /// Low-level API: Extract text blocks from an image source.
  /// 
  /// This method provides direct access to OCR functionality without
  /// document classification or structured data extraction.
  /// 
  /// Example:
  /// ```dart
  /// final textBlocks = await DocovueScanner.extractTextFromImage(
  ///   DocovueImageSource.camera,
  /// );
  /// ```
  static Future<List<DocovueTextBlock>> extractTextFromImage(
    DocovueImageSource source, {
    List<String> languages = const ['en'],
    String? imagePath,
  }) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('extractText', {
        'source': source.name,
        'languages': languages,
        'imagePath': imagePath,
      });

      if (result == null) return [];

      final textBlocksData = result['textBlocks'] as List<dynamic>? ?? [];
      
      return textBlocksData.map((blockData) {
        final data = blockData as Map<dynamic, dynamic>;
        return DocovueTextBlock(
          text: data['text'] as String,
          boundingBox: DocovueBoundingBox(
            x: (data['x'] as num).toDouble(),
            y: (data['y'] as num).toDouble(),
            width: (data['width'] as num).toDouble(),
            height: (data['height'] as num).toDouble(),
          ),
          confidence: (data['confidence'] as num).toDouble(),
          lineIndex: data['lineIndex'] as int?,
          paragraphIndex: data['paragraphIndex'] as int?,
          language: data['language'] as String?,
        );
      }).toList();

    } on PlatformException catch (e) {
      throw Exception('OCR extraction failed: ${e.message}');
    }
  }

  /// Low-level API: Detect document edges in an image.
  /// 
  /// Returns a map with 'detected' boolean and edge coordinates.
  /// Used for auto-capture to determine if document is in frame.
  static Future<Map<String, dynamic>> detectDocumentEdges(String imagePath) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('detectDocumentEdges', {
        'imagePath': imagePath,
      });
      
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      debugPrint('Edge detection failed: ${e.message}');
      return {'detected': false};
    }
  }

  /// Low-level API: Verify document liveness (anti-spoofing).
  /// 
  /// Analyzes image for signs of re-presentation attacks (photos of photos, screen displays).
  /// Returns map with 'isOriginal' boolean, confidence, and detection scores.
  static Future<Map<String, dynamic>> verifyLiveness(String imagePath) async {
    try {
      final result = await _channel.invokeMethod<Map<dynamic, dynamic>>('verifyLiveness', {
        'imagePath': imagePath,
      });
      
      return Map<String, dynamic>.from(result ?? {});
    } on PlatformException catch (e) {
      debugPrint('Liveness verification failed: ${e.message}');
      return {
        'isOriginal': false,
        'confidence': 0.0,
        'reason': 'Verification failed: ${e.message}',
      };
    }
  }

  /// Low-level API: Classify a document type from OCR text blocks.
  /// 
  /// This method analyzes OCR text to determine the most likely document type
  /// based on patterns, keywords, and validation rules.
  /// 
  /// Example:
  /// ```dart
  /// final documentType = await DocovueScanner.classifyDocument(textBlocks);
  /// ```
  static Future<DocovueDocumentType?> classifyDocument(
    List<DocovueTextBlock> blocks, {
    Set<DocovueDocumentType>? allowedTypes,
  }) async {
    if (blocks.isEmpty) return null;

    final allText = blocks.map((b) => b.normalizedText).join(' ').toLowerCase();
    final scores = <DocovueDocumentType, double>{};

    // Check each document type
    for (final type in DocovueDocumentType.values) {
      if (allowedTypes != null && !allowedTypes.contains(type)) {
        continue;
      }

      double score = 0.0;

      // Keyword matching
      for (final keyword in type.keywords) {
        if (allText.contains(keyword.toLowerCase())) {
          score += 1.0;
        }
      }

      // Pattern-specific validation
      switch (type) {
        case DocovueDocumentType.aadhaar:
          final candidates = extractAadhaarCandidates(blocks);
          for (final candidate in candidates) {
            if (isValidAadhaar(candidate.number)) {
              score += 5.0 * candidate.confidence;
            }
          }
          break;

        case DocovueDocumentType.pan:
          final candidates = extractPanCandidates(blocks);
          for (final candidate in candidates) {
            if (isValidPan(candidate.number)) {
              score += 5.0 * candidate.confidence;
            }
          }
          break;

        case DocovueDocumentType.creditCard:
        case DocovueDocumentType.debitCard:
          final candidates = extractCardCandidates(blocks);
          for (final candidate in candidates) {
            if (isValidCardNumber(candidate.number)) {
              score += 5.0 * candidate.confidence;
            }
          }
          break;

        case DocovueDocumentType.voterId:
          // Look for voter ID specific patterns
          if (allText.contains('election commission') || 
              allText.contains('elector') || 
              allText.contains('epic')) {
            score += 3.0;
          }
          // Look for voter ID number patterns
          if (RegExp(r'\b[A-Z]{3}[0-9]{7}\b').hasMatch(allText) ||
              RegExp(r'\b[A-Z]{2}[0-9]{8}\b').hasMatch(allText)) {
            score += 2.0;
          }
          break;

        case DocovueDocumentType.drivingLicense:
          // Look for driving license specific patterns
          if (allText.contains('driving licence') || 
              allText.contains('driving license') ||
              allText.contains('transport')) {
            score += 3.0;
          }
          // Look for license number patterns
          if (RegExp(r'\b[A-Z]{2}[0-9]{13}\b').hasMatch(allText) ||
              RegExp(r'\b[A-Z]{2}[0-9]{2}[0-9]{11}\b').hasMatch(allText)) {
            score += 2.0;
          }
          break;

        case DocovueDocumentType.passport:
          // Look for MRZ patterns
          for (final block in blocks) {
            if (_isMrzLine(block.text)) {
              score += 3.0 * block.confidence;
            }
          }
          break;

        default:
          // Generic scoring based on keywords only
          break;
      }

      if (score > 0) {
        scores[type] = score;
      }
    }

    if (scores.isEmpty) return null;

    // Return the type with the highest score
    final bestType = scores.entries.reduce((a, b) => a.value > b.value ? a : b).key;
    
    // Require minimum score for classification
    return scores[bestType]! >= 2.0 ? bestType : null;
  }

  /// Low-level API: Extract structured data from OCR text blocks for a specific document type.
  /// 
  /// This method performs field extraction and validation for the specified document type.
  /// 
  /// Example:
  /// ```dart
  /// final document = await DocovueScanner.extractDocumentData(
  ///   DocovueDocumentType.aadhaar,
  ///   textBlocks,
  /// );
  /// ```
  static Future<DocovueDocument?> extractDocumentData(
    DocovueDocumentType type,
    List<DocovueTextBlock> blocks, {
    DocovueScannerConfig? config,
  }) async {
    if (blocks.isEmpty) return null;

    switch (type) {
      case DocovueDocumentType.aadhaar:
        return _extractAadhaarData(blocks, config);
      case DocovueDocumentType.pan:
        return _extractPanData(blocks, config);
      case DocovueDocumentType.voterId:
        return _extractVoterIdData(blocks, config);
      case DocovueDocumentType.drivingLicense:
        return _extractDrivingLicenseData(blocks, config);
      case DocovueDocumentType.creditCard:
      case DocovueDocumentType.debitCard:
        return _extractCardData(blocks, config);
      case DocovueDocumentType.passport:
        return _extractPassportData(blocks, config);
      case DocovueDocumentType.invoice:
        return _extractInvoiceData(blocks, config);
      case DocovueDocumentType.receipt:
        return _extractReceiptData(blocks, config);
      case DocovueDocumentType.healthInsuranceCard:
        return _extractHealthInsuranceData(blocks, config);
      case DocovueDocumentType.labReport:
        return _extractLabReportData(blocks, config);
      default:
        return _extractGenericData(blocks, config);
    }
  }

  // Private helper methods

  static Future<bool> _showConsentDialog(BuildContext context, DocovueScannerConfig config) async {
    return await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(config.consentDialogTitle ?? DocovueScannerConfig.defaultConsentTitle),
        content: Text(config.consentDialogMessage ?? DocovueScannerConfig.defaultConsentMessage),
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

  static Future<List<DocovueTextBlock>> _captureAndExtractText(DocovueScannerConfig config) async {
    // This would typically show a camera interface or file picker
    // For now, we'll simulate with a platform channel call
    return await extractTextFromImage(
      DocovueImageSource.camera,
      languages: config.allowedLanguages,
    );
  }

  static DocovueScanErrorType _mapPlatformException(PlatformException e) {
    switch (e.code) {
      case 'CAMERA_PERMISSION_DENIED':
        return const CameraPermissionDenied();
      case 'CAMERA_NOT_AVAILABLE':
        return const CameraNotAvailable();
      case 'USER_CANCELLED':
        return const UserCancelled();
      case 'TIMEOUT':
        return const ScanTimeout();
      default:
        return GenericError(e.message ?? 'Unknown error');
    }
  }

  static bool _isMrzLine(String text) {
    // Simplified MRZ detection - production code should be more comprehensive
    final cleanText = text.replaceAll(' ', '');
    return cleanText.length >= 30 && 
           RegExp(r'^[A-Z0-9<]+$').hasMatch(cleanText) &&
           cleanText.contains('<');
  }

  static String _maskCardNumber(String cardNumber) {
    if (cardNumber.length < 8) return '*' * cardNumber.length;
    final last4 = cardNumber.substring(cardNumber.length - 4);
    final masked = '*' * (cardNumber.length - 4);
    return '$masked$last4';
  }

  static DocovueAadhaarData? _extractAadhaarData(List<DocovueTextBlock> blocks, DocovueScannerConfig? config) {
    final allText = blocks.map((b) => b.text).join(' ');
    print('Aadhaar OCR text: $allText');

    // Extract Aadhaar number - look for 12-digit sequences (most reliable approach)
    String? aadhaarNumber;
    double aadhaarConfidence = 0.0;
    
    // Look for 12-digit patterns (with or without spaces)
    final numberPatterns = [
      RegExp(r'\b\d{4}\s*\d{4}\s*\d{4}\b'),           // 4-4-4 pattern
      RegExp(r'\b\d{12}\b'),                           // 12 digits together
      RegExp(r'\b\d{4}[\s-]\d{4}[\s-]\d{4}\b'),      // With separators
    ];
    
    for (final pattern in numberPatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        final cleanNumber = match.group(0)!.replaceAll(RegExp(r'[\s-]'), '');
        if (cleanNumber.length == 12) {
          aadhaarNumber = cleanNumber;
          aadhaarConfidence = 0.9;
          print('Found Aadhaar number: $aadhaarNumber');
          break;
        }
      }
    }
    
    // If no 12-digit found, try extracting from longer sequences
    if (aadhaarNumber == null) {
      final longPattern = RegExp(r'\b\d{4}\s*\d{4}\s*\d{4}\s*\d{1,4}\b');
      final match = longPattern.firstMatch(allText);
      if (match != null) {
        final cleanNumber = match.group(0)!.replaceAll(RegExp(r'\s'), '');
        if (cleanNumber.length >= 12) {
          // Take last 12 digits (most common case)
          aadhaarNumber = cleanNumber.substring(cleanNumber.length - 12);
          aadhaarConfidence = 0.7;
          print('Extracted Aadhaar from longer sequence: $aadhaarNumber');
        }
      }
    }

    if (aadhaarNumber == null) {
      print('No Aadhaar number found');
      return null;
    }

    // Extract name - multiple strategies
    String name = 'Name not detected';
    double nameConfidence = 0.0;
    
    // Strategy 1: Look between "Aadhaar" and "Male/Female"
    var nameMatch = RegExp(r'Aadhaar\s+([A-Za-z\s]+?)\s+(Male|Female)', caseSensitive: false).firstMatch(allText);
    if (nameMatch != null) {
      name = nameMatch.group(1)!.trim();
      nameConfidence = 0.9;
    } else {
      // Strategy 2: Look for capitalized names
      nameMatch = RegExp(r'\b([A-Z][a-z]+\s+[A-Z][a-z]+(?:\s+[A-Z][a-z]+)?)\b').firstMatch(allText);
      if (nameMatch != null) {
        final candidate = nameMatch.group(1)!;
        if (!candidate.contains('GOVERNMENT') && !candidate.contains('INDIA')) {
          name = candidate;
          nameConfidence = 0.7;
        }
      }
    }

    // Extract gender
    String? gender;
    final genderMatch = RegExp(r'\b(Male|Female)\b', caseSensitive: false).firstMatch(allText);
    if (genderMatch != null) {
      gender = genderMatch.group(1)!;
    }

    // Extract address - look for location patterns
    String? address;
    final locationMatch = RegExp(r'(Male|Female)\s+([^0-9]+?)\s+\d{4}', caseSensitive: false).firstMatch(allText);
    if (locationMatch != null) {
      address = locationMatch.group(2)?.trim();
    }

    // Extract DOB - look for date patterns
    String dob = 'DOB not detected';
    final dobMatch = RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{4}\b').firstMatch(allText);
    if (dobMatch != null) {
      dob = dobMatch.group(0)!;
    }

    print('Extracted - Name: $name, Number: $aadhaarNumber, Gender: $gender, Address: $address');

    return DocovueAadhaarData(
      aadhaarNumber: aadhaarNumber,
      name: name,
      dateOfBirth: dob,
      gender: gender,
      address: address,
      numberConfidence: aadhaarConfidence,
      nameConfidence: nameConfidence,
      dobConfidence: dobMatch != null ? 0.8 : 0.0,
      genderConfidence: gender != null ? 0.8 : null,
      addressConfidence: address != null ? 0.7 : null,
    );
  }

  static DocovuePanData? _extractPanData(List<DocovueTextBlock> blocks, DocovueScannerConfig? config) {
    final allText = blocks.map((b) => b.text).join(' ');
    print('PAN OCR text: $allText');

    // Extract PAN number - multiple strategies for reliability
    String? panNumber;
    double panConfidence = 0.0;
    
    // Strategy 1: Look for 10-character alphanumeric sequences
    final panPatterns = [
      RegExp(r'\b[A-Z]{5}[0-9]{4}[A-Z]\b'),          // Perfect PAN format
      RegExp(r'\b[A-Z0-9]{10}\b'),                    // Any 10 alphanumeric
      RegExp(r'\b[A-Z]{3,7}[0-9]{2,6}[A-Z0-9]{1,3}\b'), // Flexible pattern
    ];
    
    for (final pattern in panPatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        final candidate = match.group(0)!;
        if (candidate.length == 10) {
          panNumber = candidate;
          panConfidence = isValidPan(candidate) ? 0.9 : 0.7;
          print('Found PAN: $panNumber (valid format: ${isValidPan(candidate)})');
          break;
        }
      }
    }

    if (panNumber == null) {
      print('No PAN number found');
      return null;
    }

    // Extract name - look after "Name" keyword
    String name = 'Name not detected';
    double nameConfidence = 0.0;
    
    // Strategy 1: Look for name after "Name" keyword
    var nameMatch = RegExp(r'Name\s+([A-Z\s]+?)(?:\s+fot|\s+Father|\s+Date|\s+Permanent|\s+\d)', caseSensitive: false).firstMatch(allText);
    if (nameMatch != null) {
      name = nameMatch.group(1)!.trim();
      nameConfidence = 0.9;
    } else {
      // Strategy 2: Look for capitalized names
      nameMatch = RegExp(r'\b([A-Z][A-Z\s]+[A-Z])\b').firstMatch(allText);
      if (nameMatch != null) {
        final candidate = nameMatch.group(1)!;
        if (!candidate.contains('INCOME') && !candidate.contains('DEPARTMENT') && candidate.length > 5) {
          name = candidate;
          nameConfidence = 0.7;
        }
      }
    }

    // Extract father's name - look after "Father's Name" keyword
    String fatherName = 'Father name not detected';
    double fatherNameConfidence = 0.0;
    
    final fatherMatch = RegExp(r'Father.?s?\s+Name\s+([A-Z\s]+?)(?:\s+Date|\s+Permanent|\s+\d)', caseSensitive: false).firstMatch(allText);
    if (fatherMatch != null) {
      fatherName = fatherMatch.group(1)!.trim();
      fatherNameConfidence = 0.9;
    }

    // Extract date of birth - look for date patterns
    String dob = 'DOB not detected';
    double dobConfidence = 0.0;
    
    // Look for various date formats
    final dobPatterns = [
      RegExp(r'\b\d{4}-\d{2}-\d{2}\b'),              // YYYY-MM-DD
      RegExp(r'\b\d{1,2}[/-]\d{1,2}[/-]\d{4}\b'),   // DD/MM/YYYY or MM/DD/YYYY
      RegExp(r'Date\s+of\s+Birth.*?(\d{4}-\d{2}-\d{2})', caseSensitive: false),
    ];
    
    for (final pattern in dobPatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        dob = match.group(match.groupCount)!;
        dobConfidence = 0.8;
        break;
      }
    }

    print('Extracted PAN - Name: $name, Father: $fatherName, Number: $panNumber, DOB: $dob');

    return DocovuePanData(
      panNumber: panNumber,
      name: name,
      fatherName: fatherName,
      dateOfBirth: dob,
      numberConfidence: panConfidence,
      nameConfidence: nameConfidence,
      fatherNameConfidence: fatherNameConfidence,
      dobConfidence: dobConfidence,
    );
  }

  static DocovueCardData? _extractCardData(List<DocovueTextBlock> blocks, DocovueScannerConfig? config) {
    final allText = blocks.map((b) => b.text).join(' ');
    print('Card OCR text: $allText');

    // Extract card number - look for 13-19 digit sequences
    String? cardNumber;
    double cardConfidence = 0.0;
    
    final cardPatterns = [
      RegExp(r'\b\d{4}\s*\d{4}\s*\d{4}\s*\d{4}\b'),     // 16 digits with spaces
      RegExp(r'\b\d{13,19}\b'),                          // 13-19 digits together
      RegExp(r'\b\d{4}[\s-]\d{4}[\s-]\d{4}[\s-]\d{3,4}\b'), // With separators
    ];
    
    for (final pattern in cardPatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        final cleanNumber = match.group(0)!.replaceAll(RegExp(r'[\s-]'), '');
        if (cleanNumber.length >= 13 && cleanNumber.length <= 19) {
          cardNumber = cleanNumber;
          cardConfidence = isValidCardNumber(cleanNumber) ? 0.9 : 0.7;
          print('Found card number: ${_maskCardNumber(cardNumber)} (valid: ${isValidCardNumber(cleanNumber)})');
          break;
        }
      }
    }

    if (cardNumber == null) {
      print('No card number found');
      return null;
    }

    // Extract cardholder name - look for name patterns
    String name = 'Name not detected';
    double nameConfidence = 0.0;
    
    final nameMatch = RegExp(r'\b([A-Z][A-Z\s]+[A-Z])\b').firstMatch(allText);
    if (nameMatch != null) {
      final candidate = nameMatch.group(1)!;
      if (!candidate.contains('BANK') && !candidate.contains('CARD') && candidate.length > 5) {
        name = candidate;
        nameConfidence = 0.8;
      }
    }

    // Extract expiry date - look for MM/YY or MM/YYYY patterns
    String expiry = 'Expiry not detected';
    double expiryConfidence = 0.0;
    
    final expiryPatterns = [
      RegExp(r'\b(0[1-9]|1[0-2])[/\s](\d{2}|\d{4})\b'),
      RegExp(r'VALID\s+THRU\s+(\d{2}/\d{2})', caseSensitive: false),
      RegExp(r'EXP\s*(\d{2}/\d{2})', caseSensitive: false),
    ];
    
    for (final pattern in expiryPatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        expiry = match.group(match.groupCount)!;
        expiryConfidence = 0.8;
        break;
      }
    }

    final cardBrand = getCardBrand(cardNumber);

    print('Extracted Card - Name: $name, Brand: $cardBrand, Expiry: $expiry');

    return DocovueCardData(
      cardNumber: cardNumber,
      expiryDate: expiry,
      cardHolderName: name,
      cardBrand: cardBrand,
      numberConfidence: cardConfidence,
      expiryConfidence: expiryConfidence,
      nameConfidence: nameConfidence,
      brandConfidence: 0.9,
    );
  }

  static DocovueGenericDocumentData? _extractPassportData(List<DocovueTextBlock> blocks, DocovueScannerConfig? config) {
    final allText = blocks.map((b) => b.text).join(' ');
    print('Passport OCR text: $allText');

    final detectedFields = <String, DetectedField>{};

    // Extract passport number - look for alphanumeric patterns
    final passportPatterns = [
      RegExp(r'\bPassport\s*(?:No|Number)[:\s]*([A-Z0-9]{6,9})\b', caseSensitive: false),
      RegExp(r'\b([A-Z][0-9]{7,8})\b'),  // Common format: A1234567
    ];
    
    for (final pattern in passportPatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        detectedFields['passport_number'] = DetectedField(
          value: match.group(1)!,
          confidence: 0.9,
          type: DetectedFieldType.number,
          rawText: match.group(0),
        );
        break;
      }
    }

    // Extract full name
    final nameCandidates = extractNameCandidates(blocks);
    if (nameCandidates.isNotEmpty) {
      detectedFields['name'] = DetectedField(
        value: nameCandidates.first.name,
        confidence: nameCandidates.first.confidence,
        type: DetectedFieldType.name,
        boundingBox: nameCandidates.first.boundingBox,
        rawText: nameCandidates.first.rawText,
      );
    }

    // Extract dates (DOB, issue, expiry)
    final dateCandidates = extractDateCandidates(blocks);
    for (int i = 0; i < dateCandidates.length && i < 3; i++) {
      final label = i == 0 ? 'date_of_birth' : i == 1 ? 'date_of_issue' : 'date_of_expiry';
      detectedFields[label] = DetectedField(
        value: dateCandidates[i].date,
        confidence: dateCandidates[i].confidence,
        type: DetectedFieldType.date,
        boundingBox: dateCandidates[i].boundingBox,
        rawText: dateCandidates[i].rawText,
      );
    }

    print('Extracted Passport fields: ${detectedFields.keys.join(', ')}');

    return DocovueGenericDocumentData(
      rawText: allText,
      textBlocks: blocks,
      detectedFields: detectedFields,
      documentHints: ['Passport', 'International Travel Document'],
      extractionConfidence: detectedFields.isNotEmpty ? 0.75 : 0.5,
      suggestedDocumentType: 'Passport',
    );
  }

  static DocovueGenericDocumentData _extractInvoiceData(List<DocovueTextBlock> blocks, DocovueScannerConfig? config) {
    final allText = blocks.map((b) => b.text).join(' ');
    print('Invoice OCR text: $allText');

    final detectedFields = <String, DetectedField>{};

    // Extract invoice number
    final invoiceMatch = RegExp(r'Invoice\s*(?:No|Number|#)[:\s]*([A-Z0-9-]+)', caseSensitive: false).firstMatch(allText);
    if (invoiceMatch != null) {
      detectedFields['invoice_number'] = DetectedField(
        value: invoiceMatch.group(1)!,
        confidence: 0.9,
        type: DetectedFieldType.number,
        rawText: invoiceMatch.group(0),
      );
    }

    // Extract total amount
    final amountPatterns = [
      RegExp(r'Total[:\s]*(?:Rs\.?|₹|INR)?\s*([\d,]+\.?\d*)', caseSensitive: false),
      RegExp(r'Amount[:\s]*(?:Rs\.?|₹|INR)?\s*([\d,]+\.?\d*)', caseSensitive: false),
    ];
    
    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        detectedFields['total_amount'] = DetectedField(
          value: match.group(1)!,
          confidence: 0.9,
          type: DetectedFieldType.amount,
          rawText: match.group(0),
        );
        break;
      }
    }

    // Extract date
    final dateCandidates = extractDateCandidates(blocks);
    if (dateCandidates.isNotEmpty) {
      detectedFields['date'] = DetectedField(
        value: dateCandidates.first.date,
        confidence: dateCandidates.first.confidence,
        type: DetectedFieldType.date,
        boundingBox: dateCandidates.first.boundingBox,
        rawText: dateCandidates.first.rawText,
      );
    }

    return DocovueGenericDocumentData(
      rawText: allText,
      textBlocks: blocks,
      detectedFields: detectedFields,
      documentHints: ['Invoice', 'Bill'],
      extractionConfidence: detectedFields.isNotEmpty ? 0.7 : 0.5,
      suggestedDocumentType: 'Invoice',
    );
  }

  static DocovueGenericDocumentData _extractReceiptData(List<DocovueTextBlock> blocks, DocovueScannerConfig? config) {
    final allText = blocks.map((b) => b.text).join(' ');
    print('Receipt OCR text: $allText');

    final detectedFields = <String, DetectedField>{};

    // Extract receipt/transaction number
    final receiptMatch = RegExp(r'(?:Receipt|Transaction|Ref)\s*(?:No|Number|#|ID)[:\s]*([A-Z0-9-]+)', caseSensitive: false).firstMatch(allText);
    if (receiptMatch != null) {
      detectedFields['receipt_number'] = DetectedField(
        value: receiptMatch.group(1)!,
        confidence: 0.9,
        type: DetectedFieldType.number,
        rawText: receiptMatch.group(0),
      );
    }

    // Extract amount
    final amountMatch = RegExp(r'(?:Total|Amount|Paid)[:\s]*(?:Rs\.?|₹|INR|\$)?\s*([\d,]+\.?\d*)', caseSensitive: false).firstMatch(allText);
    if (amountMatch != null) {
      detectedFields['amount'] = DetectedField(
        value: amountMatch.group(1)!,
        confidence: 0.9,
        type: DetectedFieldType.amount,
        rawText: amountMatch.group(0),
      );
    }

    // Extract date
    final dateCandidates = extractDateCandidates(blocks);
    if (dateCandidates.isNotEmpty) {
      detectedFields['date'] = DetectedField(
        value: dateCandidates.first.date,
        confidence: dateCandidates.first.confidence,
        type: DetectedFieldType.date,
        boundingBox: dateCandidates.first.boundingBox,
        rawText: dateCandidates.first.rawText,
      );
    }

    return DocovueGenericDocumentData(
      rawText: allText,
      textBlocks: blocks,
      detectedFields: detectedFields,
      documentHints: ['Receipt', 'Payment Confirmation'],
      extractionConfidence: detectedFields.isNotEmpty ? 0.7 : 0.5,
      suggestedDocumentType: 'Receipt',
    );
  }

  static DocovueGenericDocumentData _extractHealthInsuranceData(List<DocovueTextBlock> blocks, DocovueScannerConfig? config) {
    final allText = blocks.map((b) => b.text).join(' ');
    print('Health Insurance OCR text: $allText');

    final detectedFields = <String, DetectedField>{};

    // Extract policy/member number
    final policyMatch = RegExp(r'(?:Policy|Member|ID)\s*(?:No|Number)[:\s]*([A-Z0-9-]+)', caseSensitive: false).firstMatch(allText);
    if (policyMatch != null) {
      detectedFields['policy_number'] = DetectedField(
        value: policyMatch.group(1)!,
        confidence: 0.9,
        type: DetectedFieldType.number,
        rawText: policyMatch.group(0),
      );
    }

    // Extract member name
    final nameCandidates = extractNameCandidates(blocks);
    if (nameCandidates.isNotEmpty) {
      detectedFields['member_name'] = DetectedField(
        value: nameCandidates.first.name,
        confidence: nameCandidates.first.confidence,
        type: DetectedFieldType.name,
        boundingBox: nameCandidates.first.boundingBox,
        rawText: nameCandidates.first.rawText,
      );
    }

    // Extract validity/expiry date
    final dateCandidates = extractDateCandidates(blocks);
    if (dateCandidates.isNotEmpty) {
      detectedFields['validity'] = DetectedField(
        value: dateCandidates.first.date,
        confidence: dateCandidates.first.confidence,
        type: DetectedFieldType.date,
        boundingBox: dateCandidates.first.boundingBox,
        rawText: dateCandidates.first.rawText,
      );
    }

    return DocovueGenericDocumentData(
      rawText: allText,
      textBlocks: blocks,
      detectedFields: detectedFields,
      documentHints: ['Health Insurance', 'Medical Coverage'],
      extractionConfidence: detectedFields.isNotEmpty ? 0.75 : 0.5,
      suggestedDocumentType: 'Health Insurance Card',
    );
  }

  static DocovueGenericDocumentData _extractLabReportData(List<DocovueTextBlock> blocks, DocovueScannerConfig? config) {
    final allText = blocks.map((b) => b.text).join(' ');
    print('Lab Report OCR text: $allText');

    final detectedFields = <String, DetectedField>{};

    // Extract patient name
    final nameMatch = RegExp(r'Patient\s*(?:Name)?[:\s]*([A-Z][a-z]+(?:\s+[A-Z][a-z]+)+)', caseSensitive: false).firstMatch(allText);
    if (nameMatch != null) {
      detectedFields['patient_name'] = DetectedField(
        value: nameMatch.group(1)!.trim(),
        confidence: 0.9,
        type: DetectedFieldType.name,
        rawText: nameMatch.group(0),
      );
    }

    // Extract report ID/number
    final reportMatch = RegExp(r'(?:Report|Lab|Test)\s*(?:No|Number|ID)[:\s]*([A-Z0-9-]+)', caseSensitive: false).firstMatch(allText);
    if (reportMatch != null) {
      detectedFields['report_number'] = DetectedField(
        value: reportMatch.group(1)!,
        confidence: 0.9,
        type: DetectedFieldType.number,
        rawText: reportMatch.group(0),
      );
    }

    // Extract report date
    final dateCandidates = extractDateCandidates(blocks);
    if (dateCandidates.isNotEmpty) {
      detectedFields['report_date'] = DetectedField(
        value: dateCandidates.first.date,
        confidence: dateCandidates.first.confidence,
        type: DetectedFieldType.date,
        boundingBox: dateCandidates.first.boundingBox,
        rawText: dateCandidates.first.rawText,
      );
    }

    return DocovueGenericDocumentData(
      rawText: allText,
      textBlocks: blocks,
      detectedFields: detectedFields,
      documentHints: ['Lab Report', 'Medical Test Results'],
      extractionConfidence: detectedFields.isNotEmpty ? 0.7 : 0.5,
      suggestedDocumentType: 'Lab Report',
    );
  }

  static DocovueGenericDocumentData _extractVoterIdData(List<DocovueTextBlock> blocks, DocovueScannerConfig? config) {
    final allText = blocks.map((b) => b.text).join(' ');
    print('Voter ID OCR text: $allText');

    final detectedFields = <String, DetectedField>{};

    // Extract voter ID number - look for EPIC number patterns
    final voterIdPatterns = [
      RegExp(r'\b([A-Z]{3}[0-9]{7})\b'),              // ABC1234567 format
      RegExp(r'\b([A-Z]{2}[0-9]{8})\b'),              // AB12345678 format
      RegExp(r'EPIC[:\s]*([A-Z0-9]{10})', caseSensitive: false),
    ];
    
    for (final pattern in voterIdPatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        detectedFields['voter_id_number'] = DetectedField(
          value: match.group(1)!,
          confidence: 0.9,
          type: DetectedFieldType.number,
          rawText: match.group(0),
        );
        break;
      }
    }

    // Extract name - look after "Name" keyword
    final nameMatch = RegExp(r'Name\s*[:]\s*([A-Z\s]+?)(?:\s+[A-Z]{3}[0-9]|\s+EPIC|\s+Father)', caseSensitive: false).firstMatch(allText);
    if (nameMatch != null) {
      detectedFields['name'] = DetectedField(
        value: nameMatch.group(1)!.trim(),
        confidence: 0.9,
        type: DetectedFieldType.name,
        rawText: nameMatch.group(0),
      );
    }

    // Extract father's name
    final fatherMatch = RegExp(r'Father.?s?\s+Name\s*[:]\s*([A-Z\s]+?)(?:\s+[A-Z]{3}[0-9]|\s+EPIC|\s+Age)', caseSensitive: false).firstMatch(allText);
    if (fatherMatch != null) {
      detectedFields['father_name'] = DetectedField(
        value: fatherMatch.group(1)!.trim(),
        confidence: 0.9,
        type: DetectedFieldType.name,
        rawText: fatherMatch.group(0),
      );
    }

    // Extract age or date of birth
    final ageMatch = RegExp(r'Age\s*[:]\s*(\d{1,3})', caseSensitive: false).firstMatch(allText);
    if (ageMatch != null) {
      detectedFields['age'] = DetectedField(
        value: ageMatch.group(1)!,
        confidence: 0.8,
        type: DetectedFieldType.number,
        rawText: ageMatch.group(0),
      );
    }

    print('Extracted Voter ID fields: ${detectedFields.keys.join(', ')}');

    return DocovueGenericDocumentData(
      rawText: allText,
      textBlocks: blocks,
      detectedFields: detectedFields,
      documentHints: ['Voter ID Card', 'Election Commission of India'],
      extractionConfidence: detectedFields.isNotEmpty ? 0.8 : 0.5,
      suggestedDocumentType: 'Voter ID',
    );
  }

  static DocovueGenericDocumentData _extractDrivingLicenseData(List<DocovueTextBlock> blocks, DocovueScannerConfig? config) {
    final allText = blocks.map((b) => b.text).join(' ');
    print('Driving License OCR text: $allText');

    final detectedFields = <String, DetectedField>{};

    // Extract license number - look for DL number patterns
    final licensePatterns = [
      RegExp(r'\b([A-Z]{2}[0-9]{13})\b'),             // Standard DL format
      RegExp(r'\b([A-Z]{2}[0-9]{2}[0-9]{11})\b'),     // Alternative format
      RegExp(r'DL\s*NO[:\s]*([A-Z0-9]{15})', caseSensitive: false),
    ];
    
    for (final pattern in licensePatterns) {
      final match = pattern.firstMatch(allText);
      if (match != null) {
        detectedFields['license_number'] = DetectedField(
          value: match.group(1)!,
          confidence: 0.9,
          type: DetectedFieldType.number,
          rawText: match.group(0),
        );
        break;
      }
    }

    // Extract name
    final nameMatch = RegExp(r'Name\s*([A-Z\s]+?)(?:\s+Date|\s+Son|\s+Daughter|\s+[A-Z]{2}[0-9])', caseSensitive: false).firstMatch(allText);
    if (nameMatch != null) {
      detectedFields['name'] = DetectedField(
        value: nameMatch.group(1)!.trim(),
        confidence: 0.9,
        type: DetectedFieldType.name,
        rawText: nameMatch.group(0),
      );
    }

    // Extract date of birth
    final dobMatch = RegExp(r'Date\s+of\s+Birth\s+(\d{1,2}/\d{1,2}/\d{4})', caseSensitive: false).firstMatch(allText);
    if (dobMatch != null) {
      detectedFields['date_of_birth'] = DetectedField(
        value: dobMatch.group(1)!,
        confidence: 0.9,
        type: DetectedFieldType.date,
        rawText: dobMatch.group(0),
      );
    }

    // Extract date of issue
    final issueMatch = RegExp(r'Date\s+of\s+issue\s+(\d{1,2}/\d{1,2}/\d{4})', caseSensitive: false).firstMatch(allText);
    if (issueMatch != null) {
      detectedFields['date_of_issue'] = DetectedField(
        value: issueMatch.group(1)!,
        confidence: 0.9,
        type: DetectedFieldType.date,
        rawText: issueMatch.group(0),
      );
    }

    // Extract validity date
    final validityMatch = RegExp(r'(\d{1,2}/\d{1,2}/\d{4})(?=\s|$)', caseSensitive: false).allMatches(allText);
    if (validityMatch.length >= 2) {
      // Usually the last date is validity
      final lastDate = validityMatch.last.group(0)!;
      detectedFields['validity'] = DetectedField(
        value: lastDate,
        confidence: 0.8,
        type: DetectedFieldType.date,
        rawText: lastDate,
      );
    }

    // Extract father's/husband's name
    final relationMatch = RegExp(r'Son/Daughter/Wife\s+of\s+([A-Z\s]+?)(?:\s+Blood|\s+[A-Z]{2}[0-9]|\s+Date)', caseSensitive: false).firstMatch(allText);
    if (relationMatch != null) {
      detectedFields['father_husband_name'] = DetectedField(
        value: relationMatch.group(1)!.trim(),
        confidence: 0.9,
        type: DetectedFieldType.name,
        rawText: relationMatch.group(0),
      );
    }

    // Extract blood group
    final bloodMatch = RegExp(r'Blood\s+Group\s+([A-Z][+-]?)', caseSensitive: false).firstMatch(allText);
    if (bloodMatch != null) {
      detectedFields['blood_group'] = DetectedField(
        value: bloodMatch.group(1)!,
        confidence: 0.9,
        type: DetectedFieldType.other,
        rawText: bloodMatch.group(0),
      );
    }

    print('Extracted Driving License fields: ${detectedFields.keys.join(', ')}');

    return DocovueGenericDocumentData(
      rawText: allText,
      textBlocks: blocks,
      detectedFields: detectedFields,
      documentHints: ['Driving License', 'Transport Department'],
      extractionConfidence: detectedFields.isNotEmpty ? 0.8 : 0.5,
      suggestedDocumentType: 'Driving License',
    );
  }

  static DocovueGenericDocumentData _extractGenericData(
    List<DocovueTextBlock> blocks,
    DocovueScannerConfig? config,
  ) {
    final rawText = blocks.map((b) => b.text).join('\n');
    final detectedFields = <String, DetectedField>{};

    // Extract potential fields using heuristics
    final namesCandidates = extractNameCandidates(blocks);
    final datesCandidates = extractDateCandidates(blocks);
    final addressCandidates = extractAddressCandidates(blocks);

    // Add detected names
    for (int i = 0; i < namesCandidates.length; i++) {
      final candidate = namesCandidates[i];
      detectedFields['name_$i'] = DetectedField(
        value: candidate.name,
        confidence: candidate.confidence,
        type: DetectedFieldType.name,
        boundingBox: candidate.boundingBox,
        rawText: candidate.rawText,
      );
    }

    // Add detected dates
    for (int i = 0; i < datesCandidates.length; i++) {
      final candidate = datesCandidates[i];
      detectedFields['date_$i'] = DetectedField(
        value: candidate.date,
        confidence: candidate.confidence,
        type: DetectedFieldType.date,
        boundingBox: candidate.boundingBox,
        rawText: candidate.rawText,
      );
    }

    // Add detected addresses
    for (int i = 0; i < addressCandidates.length; i++) {
      final candidate = addressCandidates[i];
      detectedFields['address_$i'] = DetectedField(
        value: candidate.lines.join(', '),
        confidence: candidate.confidence,
        type: DetectedFieldType.address,
        boundingBox: candidate.boundingBox,
        rawText: candidate.rawText,
      );
    }

    final avgConfidence = blocks.isNotEmpty
        ? blocks.map((b) => b.confidence).reduce((a, b) => a + b) / blocks.length
        : 0.0;

    return DocovueGenericDocumentData(
      rawText: rawText,
      textBlocks: blocks,
      detectedFields: detectedFields,
      extractionConfidence: avgConfidence,
    );
  }
}

/// Image source options for document scanning.
enum DocovueImageSource {
  camera,
  gallery,
  file,
}