import 'package:meta/meta.dart';
import 'text_block.dart';

// Forward declarations
class DocovueAadhaarData extends DocovueDocument {
  const DocovueAadhaarData({
    required this.aadhaarNumber,
    required this.name,
    required this.dateOfBirth,
    this.gender,
    this.address,
    this.fatherName,
    this.phoneNumber,
    this.email,
    required this.numberConfidence,
    required this.nameConfidence,
    required this.dobConfidence,
    this.genderConfidence,
    this.addressConfidence,
    this.fatherNameConfidence,
    this.phoneConfidence,
    this.emailConfidence,
    this.isBackSide = false,
  });

  final String aadhaarNumber;
  final String name;
  final String dateOfBirth;
  final String? gender;
  final String? address;
  final String? fatherName;
  final String? phoneNumber;
  final String? email;
  final double numberConfidence;
  final double nameConfidence;
  final double dobConfidence;
  final double? genderConfidence;
  final double? addressConfidence;
  final double? fatherNameConfidence;
  final double? phoneConfidence;
  final double? emailConfidence;
  final bool isBackSide;

  @override
  double get overallConfidence {
    final scores = [
      numberConfidence,
      nameConfidence,
      if (dobConfidence > 0) dobConfidence,
      if (genderConfidence != null) genderConfidence!,
      if (addressConfidence != null) addressConfidence!,
      if (fatherNameConfidence != null) fatherNameConfidence!,
      if (phoneConfidence != null) phoneConfidence!,
      if (emailConfidence != null) emailConfidence!,
    ];
    
    return scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
  }

  String get maskedAadhaarNumber {
    if (aadhaarNumber.length != 12) return aadhaarNumber;
    return 'XXXX-XXXX-${aadhaarNumber.substring(8)}';
  }
}

class DocovuePanData extends DocovueDocument {
  const DocovuePanData({
    required this.panNumber,
    required this.name,
    required this.fatherName,
    required this.dateOfBirth,
    this.signature,
    this.photo,
    required this.numberConfidence,
    required this.nameConfidence,
    required this.fatherNameConfidence,
    required this.dobConfidence,
    this.signatureConfidence,
    this.photoConfidence,
  });

  final String panNumber;
  final String name;
  final String fatherName;
  final String dateOfBirth;
  final String? signature;
  final String? photo;
  final double numberConfidence;
  final double nameConfidence;
  final double fatherNameConfidence;
  final double dobConfidence;
  final double? signatureConfidence;
  final double? photoConfidence;

  @override
  double get overallConfidence {
    final scores = [
      numberConfidence,
      nameConfidence,
      fatherNameConfidence,
      dobConfidence,
      if (signatureConfidence != null) signatureConfidence!,
      if (photoConfidence != null) photoConfidence!,
    ];
    
    return scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
  }

  String get maskedPanNumber {
    if (panNumber.length != 10) return panNumber;
    return 'XXXXX${panNumber.substring(5, 9)}X';
  }

  /// Returns the category of PAN holder based on the 4th character.
  String get panCategory {
    if (panNumber.length < 4) return 'Unknown';
    
    switch (panNumber[3]) {
      case 'P':
        return 'Individual';
      case 'C':
        return 'Company';
      case 'H':
        return 'HUF (Hindu Undivided Family)';
      case 'F':
        return 'Firm';
      case 'A':
        return 'Association of Persons';
      case 'T':
        return 'Trust';
      case 'B':
        return 'Body of Individuals';
      case 'L':
        return 'Local Authority';
      case 'J':
        return 'Artificial Juridical Person';
      case 'G':
        return 'Government';
      default:
        return 'Other';
    }
  }
}

class DocovueCardData extends DocovueDocument {
  const DocovueCardData({
    required this.cardNumber,
    required this.expiryDate,
    required this.cardHolderName,
    required this.cardBrand,
    this.cardType,
    this.issuerBank,
    required this.numberConfidence,
    required this.expiryConfidence,
    required this.nameConfidence,
    required this.brandConfidence,
    this.typeConfidence,
    this.issuerConfidence,
  });

  final String cardNumber;
  final String expiryDate;
  final String cardHolderName;
  final String cardBrand;
  final String? cardType;
  final String? issuerBank;
  final double numberConfidence;
  final double expiryConfidence;
  final double nameConfidence;
  final double brandConfidence;
  final double? typeConfidence;
  final double? issuerConfidence;

  @override
  double get overallConfidence {
    final scores = [
      numberConfidence,
      expiryConfidence,
      nameConfidence,
      brandConfidence,
      if (typeConfidence != null) typeConfidence!,
      if (issuerConfidence != null) issuerConfidence!,
    ];
    
    return scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
  }

  String get maskedCardNumber {
    if (cardNumber.length < 8) return '*' * cardNumber.length;
    
    final last4 = cardNumber.substring(cardNumber.length - 4);
    final maskedLength = cardNumber.length - 4;
    final masked = '*' * maskedLength;
    
    final buffer = StringBuffer();
    for (int i = 0; i < masked.length; i++) {
      if (i > 0 && i % 4 == 0) buffer.write(' ');
      buffer.write(masked[i]);
    }
    if (masked.isNotEmpty) buffer.write(' ');
    buffer.write(last4);
    
    return buffer.toString();
  }
}

class DocovuePassportData extends DocovueDocument {
  const DocovuePassportData({
    required this.passportNumber,
    required this.surname,
    required this.givenNames,
    required this.nationality,
    required this.dateOfBirth,
    required this.placeOfBirth,
    required this.gender,
    required this.dateOfIssue,
    required this.dateOfExpiry,
    required this.issuingAuthority,
    this.personalNumber,
    this.mrzLine1,
    this.mrzLine2,
    this.mrzLine3,
    required this.passportNumberConfidence,
    required this.surnameConfidence,
    required this.givenNamesConfidence,
    required this.nationalityConfidence,
    required this.dobConfidence,
    required this.pobConfidence,
    required this.genderConfidence,
    required this.issueConfidence,
    required this.expiryConfidence,
    required this.authorityConfidence,
    this.personalNumberConfidence,
    this.mrzConfidence,
  });

  final String passportNumber;
  final String surname;
  final String givenNames;
  final String nationality;
  final String dateOfBirth;
  final String placeOfBirth;
  final String gender;
  final String dateOfIssue;
  final String dateOfExpiry;
  final String issuingAuthority;
  final String? personalNumber;
  final String? mrzLine1;
  final String? mrzLine2;
  final String? mrzLine3;
  final double passportNumberConfidence;
  final double surnameConfidence;
  final double givenNamesConfidence;
  final double nationalityConfidence;
  final double dobConfidence;
  final double pobConfidence;
  final double genderConfidence;
  final double issueConfidence;
  final double expiryConfidence;
  final double authorityConfidence;
  final double? personalNumberConfidence;
  final double? mrzConfidence;

  @override
  double get overallConfidence {
    final scores = [
      passportNumberConfidence,
      surnameConfidence,
      givenNamesConfidence,
      nationalityConfidence,
      dobConfidence,
      pobConfidence,
      genderConfidence,
      issueConfidence,
      expiryConfidence,
      authorityConfidence,
      if (personalNumberConfidence != null) personalNumberConfidence!,
      if (mrzConfidence != null) mrzConfidence!,
    ];
    
    return scores.isEmpty ? 0.0 : scores.reduce((a, b) => a + b) / scores.length;
  }

  String get fullName => '$givenNames $surname'.trim();

  /// Returns the country name from nationality code.
  String get countryName {
    // This is a simplified mapping - in production, use a comprehensive country code library
    const countryMap = {
      'IND': 'India',
      'USA': 'United States',
      'GBR': 'United Kingdom',
      'CAN': 'Canada',
      'AUS': 'Australia',
      'DEU': 'Germany',
      'FRA': 'France',
      'JPN': 'Japan',
      'CHN': 'China',
      'BRA': 'Brazil',
      // Add more as needed
    };
    
    return countryMap[nationality.toUpperCase()] ?? nationality;
  }
}

class DocovueGenericDocumentData extends DocovueDocument {
  const DocovueGenericDocumentData({
    required this.rawText,
    required this.textBlocks,
    this.detectedFields = const {},
    this.documentHints = const [],
    required this.extractionConfidence,
    this.suggestedDocumentType,
  });

  final String rawText;
  final List<DocovueTextBlock> textBlocks;
  final Map<String, DetectedField> detectedFields;
  final List<String> documentHints;
  final double extractionConfidence;
  final String? suggestedDocumentType;

  @override
  double get overallConfidence => extractionConfidence;
}

/// Represents a detected field in a generic document.
@immutable
class DetectedField {
  const DetectedField({
    required this.value,
    required this.confidence,
    required this.type,
    this.boundingBox,
    this.rawText,
  });

  /// The extracted field value
  final String value;

  /// Confidence score for this field (0.0 to 1.0)
  final double confidence;

  /// The type of field detected
  final DetectedFieldType type;

  /// Bounding box where this field was found (optional)
  final DocovueBoundingBox? boundingBox;

  /// Raw OCR text before processing (optional)
  final String? rawText;

  /// Returns true if this field has high confidence.
  bool get hasHighConfidence => confidence >= 0.8;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DetectedField &&
          runtimeType == other.runtimeType &&
          value == other.value &&
          confidence == other.confidence &&
          type == other.type &&
          boundingBox == other.boundingBox &&
          rawText == other.rawText;

  @override
  int get hashCode => Object.hash(value, confidence, type, boundingBox, rawText);

  @override
  String toString() => 'DetectedField('
      'value: $value, '
      'confidence: ${confidence.toStringAsFixed(2)}, '
      'type: ${type.name}'
      ')';
}

/// Types of fields that can be detected in generic documents.
enum DetectedFieldType {
  name('Name'),
  number('Number'),
  date('Date'),
  address('Address'),
  phone('Phone'),
  email('Email'),
  amount('Amount'),
  percentage('Percentage'),
  url('URL'),
  other('Other');

  const DetectedFieldType(this.displayName);

  final String displayName;
}

/// Result of a document scanning operation.
@immutable
sealed class DocovueScanResult {
  const DocovueScanResult();

  /// Executes different callbacks based on the result type.
  T when<T>({
    required T Function(DocovueDocument document) success,
    required T Function(String rawText, double confidence) unclear,
    required T Function(DocovueScanErrorType error) error,
  }) {
    return switch (this) {
      DocovueScanSuccess(document: final doc) => success(doc),
      DocovueScanUnclear(rawText: final text, confidence: final conf) => unclear(text, conf),
      DocovueScanError(error: final err) => error(err),
    };
  }

  /// Returns true if the scan was successful.
  bool get isSuccess => this is DocovueScanSuccess;

  /// Returns true if the scan result was unclear.
  bool get isUnclear => this is DocovueScanUnclear;

  /// Returns true if there was an error during scanning.
  bool get isError => this is DocovueScanError;
}

/// Successful document scan with extracted data.
@immutable
final class DocovueScanSuccess extends DocovueScanResult {
  const DocovueScanSuccess({required this.document});

  final DocovueDocument document;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocovueScanSuccess &&
          runtimeType == other.runtimeType &&
          document == other.document;

  @override
  int get hashCode => document.hashCode;

  @override
  String toString() => 'DocovueScanSuccess(document: $document)';
}

/// Scan completed but document type or data extraction was unclear.
@immutable
final class DocovueScanUnclear extends DocovueScanResult {
  const DocovueScanUnclear({
    required this.rawText,
    required this.confidence,
  });

  /// Raw OCR text that was extracted
  final String rawText;
  
  /// Overall confidence score (0.0 to 1.0)
  final double confidence;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocovueScanUnclear &&
          runtimeType == other.runtimeType &&
          rawText == other.rawText &&
          confidence == other.confidence;

  @override
  int get hashCode => Object.hash(rawText, confidence);

  @override
  String toString() => 'DocovueScanUnclear(rawText: $rawText, confidence: $confidence)';
}

/// Error occurred during document scanning.
@immutable
final class DocovueScanError extends DocovueScanResult {
  const DocovueScanError({required this.error});

  final DocovueScanErrorType error;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocovueScanError &&
          runtimeType == other.runtimeType &&
          error == other.error;

  @override
  int get hashCode => error.hashCode;

  @override
  String toString() => 'DocovueScanError(error: $error)';
}

/// Types of errors that can occur during document scanning.
@immutable
sealed class DocovueScanErrorType {
  const DocovueScanErrorType({required this.message});

  final String message;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocovueScanErrorType &&
          runtimeType == other.runtimeType &&
          message == other.message;

  @override
  int get hashCode => message.hashCode;
}

/// Camera permission was denied.
final class CameraPermissionDenied extends DocovueScanErrorType {
  const CameraPermissionDenied() : super(message: 'Camera permission denied');
}

/// Camera is not available on this device.
final class CameraNotAvailable extends DocovueScanErrorType {
  const CameraNotAvailable() : super(message: 'Camera not available');
}

/// OCR processing failed.
final class OcrProcessingFailed extends DocovueScanErrorType {
  const OcrProcessingFailed([String? details]) 
      : super(message: 'OCR processing failed${details != null ? ': $details' : ''}');
}

/// User cancelled the scanning operation.
final class UserCancelled extends DocovueScanErrorType {
  const UserCancelled() : super(message: 'User cancelled scanning');
}

/// Scanning timed out.
final class ScanTimeout extends DocovueScanErrorType {
  const ScanTimeout() : super(message: 'Scanning timed out');
}

/// Generic error with custom message.
final class GenericError extends DocovueScanErrorType {
  const GenericError(String message) : super(message: message);
}

/// Union type representing different document data types.
@immutable
sealed class DocovueDocument {
  const DocovueDocument();

  /// Executes different callbacks based on the document type.
  T map<T>({
    required T Function(DocovueAadhaarData aadhaar) aadhaar,
    required T Function(DocovuePanData pan) pan,
    required T Function(DocovueCardData card) card,
    required T Function(DocovuePassportData passport) passport,
    required T Function(DocovueGenericDocumentData generic) generic,
  }) {
    return switch (this) {
      DocovueAadhaarData() => aadhaar(this as DocovueAadhaarData),
      DocovuePanData() => pan(this as DocovuePanData),
      DocovueCardData() => card(this as DocovueCardData),
      DocovuePassportData() => passport(this as DocovuePassportData),
      DocovueGenericDocumentData() => generic(this as DocovueGenericDocumentData),
    };
  }

  /// Returns the document type.
  String get documentType {
    return switch (this) {
      DocovueAadhaarData() => 'aadhaar',
      DocovuePanData() => 'pan',
      DocovueCardData() => 'card',
      DocovuePassportData() => 'passport',
      DocovueGenericDocumentData() => 'generic',
    };
  }

  /// Returns the overall confidence score for this document.
  double get overallConfidence;

  /// Returns true if this document contains sensitive data that should be masked in logs.
  bool get containsSensitiveData => true;

  /// Returns a summary map with up to [maxFields] key fields for this document.
  ///
  /// This is useful when you only want to expose the most important values
  /// (for example, masked card number, name, and expiry for a card).
  Map<String, String> toSummary({int maxFields = 3}) {
    return map(
      aadhaar: (aadhaar) => {
        'aadhaar_number': aadhaar.maskedAadhaarNumber,
        'name': aadhaar.name,
        'date_of_birth': aadhaar.dateOfBirth,
      },
      pan: (pan) => {
        'pan_number': pan.maskedPanNumber,
        'name': pan.name,
        'date_of_birth': pan.dateOfBirth,
      },
      card: (card) => {
        'card_number': card.maskedCardNumber,
        'expiry_date': card.expiryDate,
        'card_holder_name': card.cardHolderName,
      },
      passport: (passport) => {
        'passport_number': passport.passportNumber,
        'name': passport.fullName,
        'date_of_expiry': passport.dateOfExpiry,
      },
      generic: (generic) {
        final entries = generic.detectedFields.entries.toList()
          ..sort((a, b) => b.value.confidence.compareTo(a.value.confidence));

        final limited = <String, String>{};
        for (final entry in entries.take(maxFields)) {
          limited[entry.key] = entry.value.value;
        }

        if (limited.isEmpty && generic.rawText.isNotEmpty) {
          final raw = generic.rawText;
          limited['raw_text'] = raw.length > 200
              ? '${raw.substring(0, 200)}...'
              : raw;
        }

        return limited;
      },
    );
  }
}