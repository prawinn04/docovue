# Docovue

[![pub package](https://img.shields.io/pub/v/docovue.svg)](https://pub.dev/packages/docovue)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Privacy-first document scanning and OCR plugin for Flutter with **smart auto-capture** and **anti-spoofing detection**. Supports 12+ document types with **100% on-device processing** – no cloud, no network calls, no data leaks.

## ✨ Features

### 🎯 Smart Auto-Capture
- **Automatic document detection** with edge recognition
- **Live bounding box** with color-coded feedback (White → Orange → Green)
- **Hands-free capture** – detects document and captures automatically
- **Front & back camera** support with seamless switching

### 🛡️ Anti-Spoofing / Liveness Detection
- **Prevents fraud** – detects photos of photos, screen displays, photocopies
- **Blur detection** – ensures sharp, focused images
- **Texture analysis** – verifies physical document properties
- **Reflection detection** – identifies screen glare patterns

### 📄 Supported Documents

| Document Type | Extraction | Output Fields |
|--------------|-----------|---------------|
| **Indian Documents** |
| Aadhaar Card | ⭐⭐⭐⭐⭐ Full | Number, Name, DOB |
| PAN Card | ⭐⭐⭐⭐⭐ Full | Number, Name, DOB |
| Voter ID | ⭐⭐⭐⭐ Good | ID Number, Name, Age |
| Driving License | ⭐⭐⭐⭐ Good | License No, Name, DOB |
| **Global Documents** |
| Passport | ⭐⭐⭐ Generic | Number, Name, DOB |
| National ID | ⭐⭐⭐ Generic | Top 3 fields |
| **Financial** |
| Credit/Debit Cards | ⭐⭐⭐⭐⭐ Full | Masked Number, Expiry, Name |
| Invoices | ⭐⭐⭐ Generic | Invoice No, Amount, Date |
| Receipts | ⭐⭐⭐ Generic | Receipt No, Amount, Date |
| **Healthcare** |
| Insurance Cards | ⭐⭐⭐ Generic | Policy No, Name, Validity |
| Lab Reports | ⭐⭐⭐ Generic | Patient, Report No, Date |

### 🔒 Privacy & Compliance
- ✅ **100% On-Device** – All OCR runs locally (ML Kit on Android, Vision on iOS)
- ✅ **Zero Network Calls** – No data sent to cloud services
- ✅ **No Data Storage** – Plugin doesn't cache or persist data
- ✅ **GDPR Ready** – Built-in consent dialogs
- ✅ **HIPAA Compatible** – Suitable for healthcare apps (with proper implementation)
- ✅ **PCI-DSS Friendly** – Masks sensitive card data

## 🚀 Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  docovue: ^1.0.0
```

Run:
```bash
flutter pub get
```

### Platform Setup

#### Android

Add to `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21  // ML Kit requires API 21+
    }
}

dependencies {
    implementation 'com.google.mlkit:text-recognition:16.0.0'
}
```

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

#### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app needs camera access to scan documents</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app needs photo library access to import documents</string>
```

Minimum iOS version: **11.0**

## 📖 Usage

### Basic Example – Auto-Capture Scanner

```dart
import 'package:flutter/material.dart';
import 'package:docovue/docovue.dart';

class DocumentScannerPage extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Scan Document')),
      body: DocovueScannerWidget(
        allowedTypes: const {
          DocovueDocumentType.aadhaar,
          DocovueDocumentType.pan,
          DocovueDocumentType.creditCard,
        },
        config: const DocovueScannerConfig(
          autoCapture: true,        // Enable smart auto-capture
          verifyOriginal: true,     // Enable anti-spoofing
          confidenceThreshold: 0.70,
        ),
        onResult: (result) {
          result.when(
            success: (document) {
              // Get top 3 extracted fields
              final summary = document.toSummary(maxFields: 3);
              print('Extracted: $summary');
              Navigator.pop(context, document);
            },
            unclear: (rawText, confidence) {
              print('Unclear (${(confidence * 100).toFixed(0)}%): $rawText');
            },
            error: (error) {
              print('Error: ${error.message}');
            },
          );
        },
      ),
    );
  }
}
```

### Scan from File (Gallery/Existing Image)

```dart
import 'package:image_picker/image_picker.dart';
import 'package:docovue/docovue.dart';

Future<void> scanFromGallery() async {
  // Pick image
  final picker = ImagePicker();
  final image = await picker.pickImage(source: ImageSource.gallery);
  
  if (image == null) return;

  // Scan document
  final result = await DocovueScanner.scanDocumentFromFile(
    imagePath: image.path,
    allowedTypes: const {
      DocovueDocumentType.aadhaar,
      DocovueDocumentType.passport,
    },
    config: const DocovueScannerConfig(
      verifyOriginal: false,  // Skip liveness for gallery images
      confidenceThreshold: 0.75,
    ),
  );

  result.when(
    success: (document) {
      final fields = document.toSummary(maxFields: 3);
      print('Success: $fields');
    },
    unclear: (rawText, confidence) {
      print('Could not classify document');
    },
    error: (error) {
      print('Scan error: ${error.message}');
    },
  );
}
```

### Configuration Options

```dart
// High-security mode (recommended for financial/ID documents)
DocovueScannerConfig.highSecurity()
// • verifyOriginal: true (anti-spoofing enabled)
// • confidenceThreshold: 0.90
// • maskSensitiveDataInLogs: true

// Healthcare mode (PHI/HIPAA)
DocovueScannerConfig.healthcare()
// • verifyOriginal: true
// • confidenceThreshold: 0.85

// Financial mode (PCI-DSS)
DocovueScannerConfig.financial()
// • verifyOriginal: true (fraud prevention)
// • confidenceThreshold: 0.95

// Development mode
DocovueScannerConfig.development()
// • verifyOriginal: false
// • debugMode: true

// Custom configuration
const DocovueScannerConfig(
  autoCapture: true,              // Smart auto-capture
  verifyOriginal: true,           // Anti-spoofing
  confidenceThreshold: 0.70,      // 70% minimum confidence
  showConsentDialog: true,        // GDPR consent
  maskSensitiveDataInLogs: true,  // Privacy protection
  debugMode: false,               // Debug logs
)
```

## 🎨 UI Components

### Auto-Capture Flow

```
1. User opens scanner
   ├─ WHITE bounding box: "Position document"
   
2. Document detected
   ├─ ORANGE bounding box: "Hold steady... 1/4"
   ├─ Progress counter: 2/4 → 3/4 → 4/4
   
3. Document stable
   ├─ GREEN bounding box: "Capturing!"
   ├─ Auto-captures (2 seconds total)
   
4. Liveness check (if enabled)
   ├─ "Verifying authenticity..."
   ├─ ✅ Original → Continue to OCR
   ├─ ❌ Fake → "Original ID Required" error
   
5. OCR Processing
   ├─ Extracts text using ML Kit
   ├─ Classifies document type
   ├─ Extracts structured fields
   
6. Result
   ├─ SUCCESS: Returns top 3 fields
   ├─ UNCLEAR: Shows tips + raw OCR text
   └─ ERROR: Shows error message
```

### Camera Controls

- **🔄 Camera Switch**: Toggle between front/back camera
- **⚪ AUTO Indicator**: Shows progress (1/4, 2/4, 3/4, 4/4)
- **💡 Flash**: Toggle flash/torch (back camera only)

## 🔧 Advanced Usage

### Extract Specific Document Fields

```dart
result.when(
  success: (document) {
    document.map(
      aadhaar: (aadhaar) {
        print('Aadhaar: ${aadhaar.maskedAadhaarNumber}');
        print('Name: ${aadhaar.name}');
        print('DOB: ${aadhaar.dateOfBirth}');
      },
      pan: (pan) {
        print('PAN: ${pan.maskedPanNumber}');
        print('Name: ${pan.name}');
      },
      card: (card) {
        print('Card: ${card.maskedCardNumber}');
        print('Expiry: ${card.expiryDate}');
        print('Holder: ${card.cardHolderName}');
      },
      passport: (passport) => handlePassport(passport),
      generic: (generic) {
        // Generic extraction for other document types
        print('Fields: ${generic.detectedFields}');
      },
    );
  },
);
```

### Validation Utilities

```dart
import 'package:docovue/docovue.dart';

// Validate extracted data
bool isValidAadhaar = isValidAadhaar('123456789012');
bool isValidPAN = isValidPan('ABCDE1234F');
bool isValidCard = isValidCardNumber('4111111111111111');

// Mask sensitive data
String masked = maskCardNumber('4111111111111111'); 
// Output: "**** **** **** 1111"

String maskedAadhaar = maskAadhaarNumber('123456789012'); 
// Output: "XXXX-XXXX-9012"
```

## 🛡️ Security Best Practices

### Data Handling

```dart
// ✅ DO: Use masked data in logs
print('Card scanned: ${document.maskedCardNumber}');

// ❌ DON'T: Log full sensitive data
print('Card: ${document.fullCardNumber}'); // Bad!

// ✅ DO: Enable data masking in production
DocovueScannerConfig(
  maskSensitiveDataInLogs: true,  // Always true in production
)

// ✅ DO: Enable anti-spoofing for ID/financial docs
DocovueScannerConfig(
  verifyOriginal: true,  // Prevents photo-of-photo attacks
)
```

### Compliance

**GDPR** – Show consent dialog:
```dart
DocovueScannerConfig(
  showConsentDialog: true,
  consentDialogTitle: 'Document Processing',
  consentDialogMessage: 'We process your document locally...',
)
```

**HIPAA** – Use healthcare mode:
```dart
DocovueScannerConfig.healthcare()
```

**PCI-DSS** – Never store full card numbers:
```dart
// ✅ Store masked version only
final safeData = card.toPciCompliantJson(); // Excludes full PAN
```

## 📊 Performance

- **OCR Speed**: 1-3 seconds per document
- **Auto-Capture**: 2 seconds from detection to capture
- **Memory**: ~50-100 MB during processing
- **Battery**: Minimal impact (camera + ML Kit)

## 🐛 Troubleshooting

### "Unclear Document" Issues

**Causes:**
- Poor lighting (too dark/bright)
- Document too far/close
- Blurry image (camera not focused)
- Low contrast document

**Solutions:**
```dart
// Lower confidence threshold
DocovueScannerConfig(
  confidenceThreshold: 0.60,  // Default: 0.70
)

// Enable debug mode to see raw OCR text
DocovueScannerConfig(
  debugMode: true,
)
```

### Auto-Capture Not Triggering

**Check:**
- Lighting is adequate
- Document fills 50-70% of bounding box
- Holding device steady for 2 seconds
- `autoCapture: true` in config

### Liveness Detection Too Strict

```dart
// Disable for testing
DocovueScannerConfig(
  verifyOriginal: false,
)

// Or use in specific scenarios only
verifyOriginal: documentType == DocovueDocumentType.creditCard,
```

## 🗺️ Roadmap

- [ ] iOS implementation (currently Android-optimized)
- [ ] Enhanced MRZ parsing for passports
- [ ] Batch document scanning
- [ ] Custom document type training
- [ ] Improved low-light performance

## 📄 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🆘 Support

### Contact

- **Developer**: Praveen
- **Email**: [praveenvenkat042k@gmail.com](mailto:praveenvenkat042k@gmail.com)
- **Portfolio**: [praveen-dev.space](https://praveen-dev.space)
- **Issues**: [GitHub Issues](https://github.com/prawinn04/docovue/issues)

### Contributing

Contributions welcome! Please:
1. Fork the repository
2. Create a feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

## ⚠️ Disclaimer

Docovue is not a legally certified KYC solution. OCR accuracy is best-effort. Always:
- Validate extracted data before use
- Implement proper error handling
- Follow compliance requirements for your jurisdiction
- Use human review for critical workflows

---

**Made with ❤️ for privacy-conscious developers**

[![pub package](https://img.shields.io/pub/v/docovue.svg)](https://pub.dev/packages/docovue)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

Privacy-first document scanning and OCR plugin for Flutter. Supports Aadhaar, PAN, passports, credit cards, and more with **100% on-device processing**.

## 🔒 Privacy & Compliance First

Docovue is designed from the ground up for privacy and compliance:

- **🚫 No Network Calls**: All OCR and processing happens on-device
- **🔐 No Data Storage**: Plugin doesn't persist any document data
- **📱 No Analytics**: Zero telemetry or tracking
- **🛡️ Compliance Ready**: Built for PHI/HIPAA, GDPR, and PCI-DSS environments

## ✨ Features

### Supported Documents

| Document Type | India | Global | Extraction Quality | Output Fields |
|---------------|-------|--------|-------------------|---------------|
| **Government & Identity** |
| Aadhaar Card | ✅ | - | ⭐⭐⭐⭐⭐ Full | Number, Name, DOB |
| PAN Card | ✅ | - | ⭐⭐⭐⭐⭐ Full | Number, Name, DOB |
| Voter ID | ✅ | - | ⭐⭐⭐⭐ Good | ID Number, Name, Age |
| Driving License | ✅ | ✅ | ⭐⭐⭐⭐ Good | License No, Name, DOB |
| Passport | ✅ | ✅ | ⭐⭐⭐ Generic | Number, Name, DOB |
| National ID | - | ✅ | ⭐⭐⭐ Generic | Top 3 detected fields |
| **Financial** |
| Credit Cards | ✅ | ✅ | ⭐⭐⭐⭐⭐ Full | Number, Expiry, Name |
| Debit Cards | ✅ | ✅ | ⭐⭐⭐⭐⭐ Full | Number, Expiry, Name |
| Invoices | ✅ | ✅ | ⭐⭐⭐ Generic | Invoice No, Amount, Date |
| Receipts | ✅ | ✅ | ⭐⭐⭐ Generic | Receipt No, Amount, Date |
| **Healthcare** |
| Insurance Cards | ✅ | ✅ | ⭐⭐⭐ Generic | Policy No, Name, Validity |
| Lab Reports | ✅ | ✅ | ⭐⭐⭐ Generic | Patient, Report No, Date |

**Legend**:  
⭐⭐⭐⭐⭐ **Full Support**: Dedicated extraction with high-confidence field-level validation  
⭐⭐⭐⭐ **Good Support**: Returns as Generic with strong pattern matching  
⭐⭐⭐ **Generic Support**: Returns top 3 detected fields from OCR text

### Key Features

- **🎯 High-Level API**: Simple one-line document scanning
- **🔧 Low-Level API**: Advanced OCR and classification control
- **📱 Live Camera Widget**: Auto-capture with bounding box guides
- **🛡️ Anti-Spoofing**: Liveness detection to verify physical documents
- **📊 Smart Output**: Returns only top 3 most important fields
- **✅ Smart Validation**: Luhn, Verhoeff, and format validation
- **🎨 Form Binding**: Auto-populate form controllers
- **🌍 Multi-Language**: Support for English, Hindi, and more
- **⚡ Fast Processing**: Optimized on-device OCR

## 🚀 Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  docovue: ^1.0.0
```

### Basic Usage

```dart
import 'package:docovue/docovue.dart';

// Simple document scanning
final result = await DocovueScanner.scanDocument(
  context: context,
  allowedTypes: const {
    DocovueDocumentType.aadhaar,
    DocovueDocumentType.pan,
    DocovueDocumentType.creditCard,
  },
  config: const DocovueScannerConfig(
    showConsentDialog: true,
    maskSensitiveDataInLogs: true,
  ),
);

// Handle results
result.when(
  success: (document) {
    document.map(
      aadhaar: (aadhaar) {
        print('Aadhaar: ${aadhaar.maskedAadhaarNumber}');
        print('Name: ${aadhaar.name}');
        
        // Auto-populate form
        aadhaar.bindToForm(
          nameController: nameController,
          aadhaarController: aadhaarController,
          dobController: dobController,
        );
      },
      pan: (pan) => handlePanCard(pan),
      card: (card) => handleCreditCard(card),
      passport: (passport) => handlePassport(passport),
      generic: (generic) => handleGenericDocument(generic),
    );
  },
  unclear: (rawText, confidence) {
    // Show manual review UI
    showManualReview(rawText, confidence);
  },
  error: (error) {
    // Handle error
    showError(error.message);
  },
);
```

### Using the Scanner Widget

```dart
// Live camera scanner with auto-capture and liveness detection
DocovueScannerWidget(
  allowedTypes: const {
    DocovueDocumentType.aadhaar,
    DocovueDocumentType.pan,
    DocovueDocumentType.creditCard,
  },
  config: const DocovueScannerConfig(
    verifyOriginal: true,  // Enable anti-spoofing
    autoCapture: true,     // Enable auto-capture
    confidenceThreshold: 0.85,
  ),
  onResult: (result) {
    result.when(
      success: (document) {
        // Get only top 3 fields
        final summary = document.toSummary(maxFields: 3);
        print(summary); // {"number": "XXXX-1234", "name": "John", "dob": "01/01/1990"}
      },
      unclear: (rawText, confidence) => handleUnclear(),
      error: (error) => handleError(error),
    );
  },
)
```

### Scan from File (Gallery/Existing Image)

```dart
// Process an existing image file
final result = await DocovueScanner.scanDocumentFromFile(
  imagePath: '/path/to/image.jpg',
  allowedTypes: const {
    DocovueDocumentType.aadhaar,
    DocovueDocumentType.passport,
    DocovueDocumentType.invoice,
  },
  config: const DocovueScannerConfig(
    verifyOriginal: false, // Skip liveness check for gallery images
    confidenceThreshold: 0.75,
  ),
);

result.when(
  success: (document) {
    // Returns only top 3 most important fields
    final topFields = document.toSummary(maxFields: 3);
    print('Extracted: $topFields');
  },
  unclear: (rawText, confidence) {
    print('Could not classify document (${(confidence * 100).toFixed(0)}% confidence)');
  },
  error: (error) {
    print('Scan error: ${error.message}');
  },
);
```

## 📖 Usage

### Configuration Options

```dart
// High-security configuration (recommended for production)
DocovueScannerConfig.highSecurity()
// ✅ verifyOriginal: true (liveness detection enabled)
// ✅ confidenceThreshold: 0.90
// ✅ maskSensitiveDataInLogs: true

// Healthcare/PHI environments
DocovueScannerConfig.healthcare()
// ✅ verifyOriginal: true
// ✅ confidenceThreshold: 0.85

// Financial/PCI environments  
DocovueScannerConfig.financial()
// ✅ verifyOriginal: true (anti-spoofing for card fraud)
// ✅ confidenceThreshold: 0.95

// Development configuration
DocovueScannerConfig.development()
// ⚠️ verifyOriginal: false (for testing)
// ⚠️ debugMode: true

// Custom configuration
const DocovueScannerConfig(
  showConsentDialog: true,
  maskSensitiveDataInLogs: true,
  debugMode: false,
  autoCapture: true,
  verifyOriginal: true,  // Enable liveness detection
  confidenceThreshold: 0.8,
  allowedLanguages: ['en', 'hi'],
  captureTimeout: Duration(seconds: 10),
)
```

### Low-Level API

For advanced use cases, you can use the low-level API:

```dart
// Extract text from image
final textBlocks = await DocovueScanner.extractTextFromImage(
  DocovueImageSource.camera,
);

// Classify document type
final documentType = await DocovueScanner.classifyDocument(textBlocks);

// Extract structured data
final document = await DocovueScanner.extractDocumentData(
  documentType,
  textBlocks,
);
```

### Validation Utilities

```dart
// Validate document numbers
bool isValidAadhaar = isValidAadhaar('123456789012');
bool isValidPAN = isValidPan('ABCDE1234F');
bool isValidCard = isValidCardNumber('4111111111111111');

// Mask sensitive data
String masked = maskCardNumber('4111111111111111'); // **** **** **** 1111
String maskedAadhaar = maskAadhaarNumber('123456789012'); // XXXX-XXXX-9012
```

## 🔒 Security & Privacy

### What Docovue Does

✅ **On-Device Processing**: All OCR happens locally using ML Kit (Android) and Vision (iOS)  
✅ **No Network Calls**: Zero HTTP requests or external API calls  
✅ **No Data Persistence**: Plugin doesn't store images or extracted data  
✅ **Configurable Logging**: Sensitive data masking in logs  
✅ **Consent Management**: Built-in consent dialogs for GDPR compliance  

### What Docovue Does NOT Do

❌ **No Cloud OCR**: No data sent to Google, AWS, or other cloud services  
❌ **No Analytics**: No crash reporting, usage tracking, or telemetry  
❌ **No Background Processing**: No data processing when app is backgrounded  
❌ **No Caching**: No temporary storage of sensitive document data  

### Your Responsibilities

As the app developer, you are responsible for:

- **Data Handling**: How you store, process, and transmit extracted data
- **User Consent**: Obtaining proper consent for document processing
- **Compliance**: Ensuring your app meets relevant regulations (GDPR, HIPAA, PCI-DSS)
- **Security**: Implementing proper encryption and access controls for sensitive data

## 🏥 PHI / HIPAA Considerations

When processing healthcare documents:

```dart
// Use healthcare-optimized configuration
final config = DocovueScannerConfig.healthcare();

// Handle PHI data appropriately
result.when(
  success: (document) {
    // Ensure PHI is handled according to HIPAA requirements
    // - Encrypt data at rest and in transit
    // - Implement proper access controls
    // - Maintain audit logs
    // - Follow minimum necessary principle
  },
);
```

**Important**: Docovue provides the tools for secure document scanning, but HIPAA compliance requires proper implementation throughout your entire application and infrastructure.

## 🌍 GDPR Considerations

For GDPR compliance:

```dart
const config = DocovueScannerConfig(
  showConsentDialog: true, // Required for GDPR
  consentDialogTitle: 'Document Processing Consent',
  consentDialogMessage: 'Your custom GDPR-compliant consent message...',
);
```

**GDPR Rights**: Your app must handle user rights including access, rectification, erasure, and data portability for any extracted document data you store.

## 💳 PCI-DSS & Card Scanning

When scanning payment cards:

```dart
// Use financial-optimized configuration
final config = DocovueScannerConfig.financial();

result.when(
  success: (document) {
    document.map(
      card: (card) {
        // Use PCI-compliant data handling
        final safeData = card.toPciCompliantJson(); // Excludes full PAN
        
        // Never log full card numbers
        print('Card: ${card.maskedCardNumber}');
        
        // For PCI compliance:
        // - Never store full PAN unless you're PCI-compliant
        // - Use tokenization for card storage
        // - Implement proper network security
        // - Follow PCI-DSS requirements
      },
    );
  },
);
```

**Warning**: Card scanning is for UI convenience only. If you store or process card details, you must ensure your backend and application are PCI-DSS compliant.

## 🛠️ Platform Setup

### Android

Add to `android/app/build.gradle`:

```gradle
android {
    compileSdkVersion 34
    
    defaultConfig {
        minSdkVersion 21 // ML Kit requires API 21+
    }
}

dependencies {
    implementation 'com.google.mlkit:text-recognition:16.0.0'
}
```

Add to `android/app/src/main/AndroidManifest.xml`:

```xml
<uses-permission android:name="android.permission.CAMERA" />
<uses-feature android:name="android.hardware.camera" android:required="true" />
```

### iOS

Add to `ios/Runner/Info.plist`:

```xml
<key>NSCameraUsageDescription</key>
<string>This app uses the camera to scan documents for data extraction.</string>
<key>NSPhotoLibraryUsageDescription</key>
<string>This app accesses your photo library to scan documents for data extraction.</string>
```

Minimum iOS version: 11.0 (required for Vision framework)

## 🧪 Testing

```dart
// Unit tests for validators
test('should validate Aadhaar numbers', () {
  expect(isValidAadhaar('123456789012'), isTrue);
  expect(isValidAadhaar('000000000000'), isFalse);
});

// Integration tests
testWidgets('should scan document successfully', (tester) async {
  await tester.pumpWidget(MyApp());
  
  // Simulate document scanning
  final result = await DocovueScanner.scanDocument(
    context: tester.element(find.byType(MaterialApp)),
    allowedTypes: {DocovueDocumentType.aadhaar},
  );
  
  expect(result.isSuccess, isTrue);
});
```

## 🚧 Limitations

- **Accuracy**: OCR accuracy depends on image quality and document condition
- **Languages**: Limited language support (primarily English and Hindi)
- **Document Variants**: May not recognize all regional document variations
- **Real-time**: Not optimized for real-time video processing
- **Offline Only**: No cloud-based accuracy improvements

## 🗺️ Roadmap

### Version 1.1
- [ ] Enhanced MRZ parsing for passports
- [ ] Support for more Indian regional documents
- [ ] Improved address parsing
- [ ] Bank statement support

### Version 1.2
- [ ] Real-time document detection
- [ ] Custom document type training
- [ ] Batch processing support
- [ ] Enhanced error recovery

### Version 2.0
- [ ] Video-based scanning
- [ ] Document authenticity checks
- [ ] Advanced image preprocessing
- [ ] Custom ML model support

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details.

### Development Setup

```bash
git clone https://github.com/prawinn04/docovue.git
cd docovue
flutter pub get
cd example
flutter run
```

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚠️ Disclaimer

Docovue is not a legally certified KYC solution. Extraction accuracy is best effort and human review is recommended for critical workflows. Always validate extracted data before using it in production systems.

## 🆘 Support

- 📖 [Documentation](https://github.com/prawinn04/docovue#-usage)
- 🐛 [Issue Tracker](https://github.com/prawinn04/docovue/issues)
- 💬 [Discussions](https://github.com/prawinn04/docovue/discussions)
- 📧 [Email Support](mailto:praveenvenkat042k@gmail.com)

---

Made with ❤️ for privacy-conscious developers