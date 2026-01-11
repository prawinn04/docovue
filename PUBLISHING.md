# Publishing Guide for Docovue

## Prerequisites

1. **Pub.dev Account**
   - Create account at [pub.dev](https://pub.dev)
   - Verify your email

2. **Google Account** 
   - Link your Google account to pub.dev
   - Accept publisher agreement

3. **Git & GitHub**
   - GitHub account created
   - Git installed locally

4. **Flutter Environment**
   - Flutter SDK installed
   - Dart SDK (comes with Flutter)

---

## Step 1: Prepare for Publishing

### 1.1 Update Repository URL

Open `pubspec.yaml` and replace placeholders:

```yaml
homepage: https://praveen-dev.space
repository: https://github.com/YOUR_GITHUB_USERNAME/docovue
issue_tracker: https://github.com/YOUR_GITHUB_USERNAME/docovue/issues
```

Replace `YOUR_GITHUB_USERNAME` with your actual GitHub username.

### 1.2 Verify Package Structure

```bash
cd "/Users/praveen/Desktop/praveen_WorkSpace/ocr plugin/docovue"

# Check structure
ls -la

# Should see:
# ✅ pubspec.yaml
# ✅ README.md
# ✅ CHANGELOG.md
# ✅ LICENSE
# ✅ lib/
# ✅ android/
# ✅ ios/
# ✅ .gitignore
# ❌ docovue_test_app/ (excluded by .gitignore)
```

### 1.3 Run Package Analysis

```bash
# Analyze code quality
flutter pub get
dart analyze

# Check for issues
flutter pub publish --dry-run
```

Fix any warnings or errors before proceeding.

---

## Step 2: Create GitHub Repository

### 2.1 Initialize Git

```bash
cd "/Users/praveen/Desktop/praveen_WorkSpace/ocr plugin/docovue"

# Initialize (if not already done)
git init

# Add all files
git add .

# Check what will be committed (docovue_test_app should be excluded)
git status

# Commit
git commit -m "Initial release v1.0.0"
```

### 2.2 Create GitHub Repo

1. Go to [github.com/new](https://github.com/new)
2. Create repository:
   - **Name**: `docovue`
   - **Description**: Privacy-first document scanning and OCR plugin for Flutter
   - **Visibility**: Public
   - **DO NOT** initialize with README (we already have one)

3. Push to GitHub:

```bash
# Add remote (replace YOUR_GITHUB_USERNAME)
git remote add origin https://github.com/YOUR_GITHUB_USERNAME/docovue.git

# Push to main branch
git branch -M main
git push -u origin main
```

### 2.3 Verify on GitHub

Visit your repository and verify:
- ✅ README.md displays correctly
- ✅ LICENSE file is present
- ✅ Code is visible
- ❌ `docovue_test_app/` folder is NOT present (should be ignored)

---

## Step 3: Publish to Pub.dev

### 3.1 Login to Pub.dev

```bash
# Authenticate with pub.dev
dart pub login
```

This will:
1. Open browser
2. Ask you to sign in with Google
3. Grant permissions
4. Save credentials locally

### 3.2 Dry Run

```bash
cd "/Users/praveen/Desktop/praveen_WorkSpace/ocr plugin/docovue"

# Test publish (doesn't actually publish)
flutter pub publish --dry-run
```

Check output for:
- ✅ All files included
- ✅ No errors or warnings
- ✅ Package size reasonable (<10 MB recommended)
- ❌ docovue_test_app NOT included

### 3.3 Publish!

```bash
# Actual publish
flutter pub publish

# You'll be asked to confirm:
# "Publishing docovue 1.0.0 to https://pub.dev"
# Type 'y' to confirm
```

### 3.4 Verify Publication

1. Visit [pub.dev/packages/docovue](https://pub.dev/packages/docovue)
2. Check:
   - ✅ Package appears
   - ✅ README displays correctly
   - ✅ Version is 1.0.0
   - ✅ Scores (pub points, popularity, likes) will update over time

---

## Step 4: Post-Publication

### 4.1 Create Git Tag

```bash
# Tag the release
git tag -a v1.0.0 -m "Release version 1.0.0"

# Push tag to GitHub
git push origin v1.0.0
```

### 4.2 Create GitHub Release

1. Go to your repo → Releases → "Create a new release"
2. Choose tag: `v1.0.0`
3. Release title: `v1.0.0 - Initial Release`
4. Description: Copy from CHANGELOG.md
5. Click "Publish release"

### 4.3 Update Portfolio

Add to [praveen-dev.space](https://praveen-dev.space):

**Project Showcase:**
- **Name**: Docovue Flutter Plugin
- **Description**: Privacy-first document scanning with auto-capture and anti-spoofing
- **Links**: 
  - [pub.dev](https://pub.dev/packages/docovue)
  - [GitHub](https://github.com/YOUR_USERNAME/docovue)
- **Tech Stack**: Flutter, Dart, ML Kit, Kotlin
- **Features**: OCR, Auto-Capture, Liveness Detection, 12+ Document Types

---

## Step 5: Promote Your Package

### 5.1 Social Media

**Twitter/X:**
```
🚀 Just published Docovue v1.0.0 on pub.dev!

Privacy-first document scanning for Flutter:
✅ Smart auto-capture
✅ Anti-spoofing detection  
✅ 12+ document types
✅ 100% on-device processing

Check it out: https://pub.dev/packages/docovue

#FlutterDev #DartLang #OpenSource
```

**LinkedIn:**
```
Excited to announce the release of Docovue, a Flutter plugin for privacy-first document scanning!

Features:
• Smart auto-capture with edge detection
• Anti-spoofing/liveness detection
• Supports 12+ document types (Aadhaar, PAN, Passport, Credit Cards, etc.)
• 100% on-device processing (no cloud, no network calls)
• GDPR/HIPAA/PCI-DSS ready

Perfect for fintech, healthcare, and KYC applications.

📦 pub.dev/packages/docovue
💻 github.com/YOUR_USERNAME/docovue

#Flutter #OpenSource #Privacy #DocumentScanning
```

### 5.2 Flutter Communities

Post in:
- [r/FlutterDev](https://reddit.com/r/FlutterDev)
- [Flutter Community Discord](https://discord.gg/flutter)
- [Flutter Dev Google Group](https://groups.google.com/g/flutter-dev)

### 5.3 Dev.to / Medium Article

Write a tutorial:
- "Building a Privacy-First Document Scanner with Flutter"
- "How to Integrate Docovue in Your Flutter App"
- "Implementing KYC with On-Device OCR"

---

## Updating the Package (Future Releases)

### When You Make Changes

1. **Update version** in `pubspec.yaml`:
   ```yaml
   version: 1.0.1  # or 1.1.0 for new features
   ```

2. **Update CHANGELOG.md**:
   ```markdown
   ## 1.0.1
   
   ### Bug Fixes
   - Fixed issue with...
   ```

3. **Commit and push**:
   ```bash
   git add .
   git commit -m "Release v1.0.1"
   git push origin main
   git tag -a v1.0.1 -m "Release version 1.0.1"
   git push origin v1.0.1
   ```

4. **Publish update**:
   ```bash
   flutter pub publish
   ```

---

## Common Issues & Solutions

### Issue: "Package validation failed"

**Solution**: Run `dart analyze` and fix all warnings

### Issue: "Missing LICENSE file"

**Solution**: Ensure LICENSE file is in root directory

### Issue: "README too short"

**Solution**: Pub.dev requires detailed README (ours is comprehensive ✅)

### Issue: "Test app included in package"

**Solution**: Check `.gitignore` includes `docovue_test_app/`

### Issue: "Cannot authenticate"

**Solution**: 
```bash
dart pub logout
dart pub login
```

---

## Package Maintenance

### Monitor Package Health

1. **Pub.dev Dashboard**: Check pub points (aim for 130+)
2. **GitHub Issues**: Respond to user issues
3. **Pull Requests**: Review community contributions
4. **Analytics**: Track downloads and usage

### Keep Dependencies Updated

```bash
# Check for outdated dependencies
flutter pub outdated

# Update dependencies
flutter pub upgrade

# Test after updating
flutter test
```

### Respond to Users

- Answer questions in GitHub Issues
- Help with integration problems
- Consider feature requests
- Fix bugs promptly

---

## Versioning Guidelines

Follow [Semantic Versioning](https://semver.org):

- **1.0.0 → 1.0.1**: Bug fixes (PATCH)
- **1.0.0 → 1.1.0**: New features, backward compatible (MINOR)
- **1.0.0 → 2.0.0**: Breaking changes (MAJOR)

---

## Contact

**Developer**: Praveen  
**Email**: praveenvenkat042k@gmail.com  
**Portfolio**: https://praveen-dev.space  
**GitHub**: github.com/YOUR_USERNAME

---

## Checklist

Before publishing, verify:

- [ ] `pubspec.yaml` has correct info
- [ ] README.md is comprehensive
- [ ] CHANGELOG.md is updated
- [ ] LICENSE file exists
- [ ] .gitignore excludes test app
- [ ] `dart analyze` passes
- [ ] `flutter pub publish --dry-run` succeeds
- [ ] GitHub repository created
- [ ] Code pushed to GitHub
- [ ] Authenticated with pub.dev
- [ ] Published to pub.dev
- [ ] Git tag created
- [ ] GitHub release created
- [ ] Portfolio updated

---

**Congratulations! Your package is now published! 🎉**
