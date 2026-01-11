## 1.0.0

### Initial Release

#### Features
- ✅ **Smart Auto-Capture** with edge detection and document tracking
- ✅ **Anti-Spoofing / Liveness Detection** to prevent fraud
- ✅ **12+ Document Types** supported (Aadhaar, PAN, Passport, Credit Cards, etc.)
- ✅ **100% On-Device Processing** using ML Kit (Android) and Vision (iOS)
- ✅ **Privacy-First** - Zero network calls, no data storage
- ✅ **Dual Camera Support** - Front and back camera with seamless switching
- ✅ **Top 3 Fields Output** - Returns only most important extracted fields
- ✅ **Confidence-Based Results** - Success, Unclear, or Error states
- ✅ **GDPR/HIPAA/PCI-DSS Ready** - Built-in compliance features

#### Supported Documents
- Indian: Aadhaar, PAN, Voter ID, Driving License
- Global: Passport, National ID, Driver License
- Financial: Credit/Debit Cards, Invoices, Receipts
- Healthcare: Insurance Cards, Lab Reports

#### UI Components
- Live camera scanner with bounding box overlay
- Color-coded feedback (White → Orange → Green)
- Progress counter for auto-capture (1/4, 2/4, 3/4, 4/4)
- Auto-mode indicator
- Camera switch button
- Flash toggle

#### Platform Support
- Android: API 21+ (ML Kit Text Recognition)
- iOS: iOS 11+ (Vision Framework) - Coming Soon

#### Known Issues
- iOS implementation pending (Android-optimized currently)
- MRZ parsing for passports needs enhancement
- Some edge cases in low-light conditions

---

### Upcoming in v1.1.0
- Full iOS implementation
- Enhanced MRZ parsing
- Improved low-light performance
- Batch document scanning
