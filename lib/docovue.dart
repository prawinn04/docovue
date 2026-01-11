/// Privacy-first document scanning and OCR plugin for Flutter.
/// 
/// Supports on-device scanning and structured data extraction for:
/// - Indian documents (Aadhaar, PAN, Voter ID, Driving License)
/// - Global documents (Passports, National IDs, Driver's Licenses)
/// - Financial documents (Credit/Debit cards, Invoices)
/// - Healthcare documents (Insurance cards, Lab reports)
/// 
/// Key features:
/// - 100% on-device processing (no network calls)
/// - PHI/HIPAA, GDPR, PCI-DSS compliant design
/// - Configurable privacy controls
/// - High-level and low-level APIs
/// 
/// Example usage:
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
/// 
/// result.when(
///   success: (doc) => handleDocument(doc),
///   unclear: (rawText, confidence) => showManualReview(rawText),
///   error: (error) => showError(error),
/// );
/// ```
library docovue;

// Core API
export 'src/docovue_scanner.dart';

// Models
export 'src/models/document_type.dart';
export 'src/models/extraction_result.dart';
export 'src/models/text_block.dart';
export 'src/models/scanner_config.dart';

// Widgets
export 'src/widgets/docovue_scanner_widget.dart';

// Utilities (selective export for public API)
export 'src/utils/validators.dart' show 
  isValidAadhaar,
  isValidPan,
  isValidCardNumber,
  luhnCheck,
  verhoeffCheck,
  maskCardNumber,
  maskAadhaarNumber,
  maskPanNumber;