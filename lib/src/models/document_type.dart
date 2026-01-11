/// Supported document types for scanning and extraction.
enum DocovueDocumentType {
  // Indian Government & Identity Documents
  aadhaar('Aadhaar Card', 'aadhaar'),
  pan('PAN Card', 'pan'),
  voterId('Voter ID', 'voter_id'),
  drivingLicense('Driving License', 'driving_license'),
  
  // Global Identity Documents
  passport('Passport', 'passport'),
  nationalId('National ID', 'national_id'),
  globalDriverLicense('Driver License (Global)', 'global_driver_license'),
  
  // Financial Documents
  creditCard('Credit Card', 'credit_card'),
  debitCard('Debit Card', 'debit_card'),
  invoice('Invoice', 'invoice'),
  receipt('Receipt', 'receipt'),
  
  // Healthcare Documents
  healthInsuranceCard('Health Insurance Card', 'health_insurance'),
  labReport('Lab Report', 'lab_report'),
  
  // Fallback
  generic('Generic Document', 'generic');

  const DocovueDocumentType(this.displayName, this.identifier);

  /// Human-readable name for the document type
  final String displayName;
  
  /// Machine-readable identifier for the document type
  final String identifier;

  /// Returns true if this is an Indian government document
  bool get isIndianDocument => [
    aadhaar,
    pan,
    voterId,
    drivingLicense,
  ].contains(this);

  /// Returns true if this is a financial document requiring PCI-DSS considerations
  bool get isFinancialDocument => [
    creditCard,
    debitCard,
    invoice,
    receipt,
  ].contains(this);

  /// Returns true if this is a healthcare document requiring PHI/HIPAA considerations
  bool get isHealthcareDocument => [
    healthInsuranceCard,
    labReport,
  ].contains(this);

  /// Returns true if this document type contains personally identifiable information
  bool get containsPII => this != generic;

  /// Returns the confidence threshold recommended for this document type
  double get recommendedConfidenceThreshold {
    switch (this) {
      case aadhaar:
      case pan:
      case passport:
        return 0.85; // High confidence for critical ID documents
      case creditCard:
      case debitCard:
        return 0.90; // Very high confidence for financial documents
      case healthInsuranceCard:
      case labReport:
        return 0.80; // Moderate confidence for healthcare documents
      default:
        return 0.75; // Standard confidence for other documents
    }
  }

  /// Returns keywords commonly found in this document type
  List<String> get keywords {
    switch (this) {
      case aadhaar:
        return [
          'government of india',
          'unique identification',
          'aadhaar',
          'uid',
          'uidai',
        ];
      case pan:
        return [
          'income tax department',
          'permanent account number',
          'pan',
          'govt of india',
        ];
      case voterId:
        return [
          'election commission',
          'voter',
          'electoral',
          'electors',
        ];
      case drivingLicense:
        return [
          'driving licence',
          'driving license',
          'transport',
          'motor vehicle',
        ];
      case passport:
        return [
          'passport',
          'republic of',
          'government',
          'immigration',
        ];
      case creditCard:
      case debitCard:
        return [
          'visa',
          'mastercard',
          'rupay',
          'american express',
          'discover',
          'valid thru',
          'expires',
        ];
      case invoice:
        return [
          'invoice',
          'bill',
          'amount',
          'total',
          'tax',
          'gst',
        ];
      case receipt:
        return [
          'receipt',
          'paid',
          'transaction',
          'amount',
          'total',
        ];
      case healthInsuranceCard:
        return [
          'health',
          'insurance',
          'medical',
          'member',
          'policy',
        ];
      case labReport:
        return [
          'laboratory',
          'lab',
          'test',
          'report',
          'patient',
          'result',
        ];
      default:
        return [];
    }
  }
}