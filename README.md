# QR Generator — iOS QR Code App

A **native, offline** QR-code generator for iPhone built with
**SwiftUI** and Apple's **CoreImage** framework.
No server, no database, no network calls — everything runs on-device.

---

## ✨ Features

| Feature | Details |
|---|---|
| **Text / URL input** | Type any text or paste a URL — CoreImage encodes it |
| **Correction levels** | L / M / Q / H pickers (more correction = denser, more damage-resistant) |
| **Size options** | Small → X-Large scale multipliers |
| **Custom colours** | Foreground + background colour pickers via `CIPalette` |
| **Share & Save** | `ShareLink` opens the native iOS share sheet (Photos, AirDrop, Messages, …) |
| **History** | Every generation is stored and can be re-shared or deleted |
| **Dark mode** | Fully supports system dark mode |
| **Offline** | Zero network requests — CoreImage does all the QR math locally |

---

## 📂 Project Structure

```
qr code app/
├── project.yml                              # XcodeGen config
├── README.md
└── QRCodeApp/
    ├── QRCodeApp.swift                      # @main entry point
    ├── ContentView.swift                    # TabView with NavigationStack
    ├── GenerateView.swift                   # Input, options, QR display, ShareLink
    ├── HistoryView.swift                    # Scrollable list of past QR codes
    ├── QRCodeGenerator.swift                # CoreImage CIFilter.qrCodeGenerator
    ├── QRCodeItem.swift                     # Codable model for history
    ├── AppViewModel.swift                   # State + persistence
    ├── Assets.xcassets/                     # AppIcon, AccentColor
    │   ├── AppIcon.appiconset/
    │   ├── AccentColor.colorset/
    │   └── Contents.json
    ├── Preview Content/
    │   └── Preview Assets.xcassets/
    └── QRCodeGeneratorTests/
        └── QRCodeGeneratorTests.swift       # XCTest unit tests
```

---

## 🚀 How to Build & Run

### Option A — XcodeGen (recommended, one command)

1. **Install XcodeGen** (if you don't have it):
   ```bash
   brew install xcodegen
   ```

2. **Generate the project** from this folder:
   ```bash
   cd "qr code app"
   xcodegen generate
   ```

3. **Open the project**:
   ```bash
   open QRCodeApp.xcodeproj
   ```

4. In Xcode:
   - Select the **iPhone 15** simulator (or any iOS 16+ device).
   - Press **⌘R** to build and run.

### Option B — Manual Xcode setup

1. Open **Xcode** → **File → New → Project**.
2. Choose **iOS → App** → Next.
3. Set:
   - **Product Name**: `QR Generator`
   - **Interface**: **SwiftUI**
   - **Language**: **Swift**
   - **Minimum Deployment Target**: **iOS 16.0**
4. Click **Create**.
5. In the navigator, delete the auto-generated `ContentView.swift`.
6. **Drag every `.swift` file** from the `QRCodeApp/` folder into the
   **QRCodeApp** target group in Xcode (make sure "Target: QR Generator"
   is checked when the dialog appears).
7. Drag the `Assets.xcassets` and `Preview Content/` folders into the project.
8. Add the test folder files to the **QRCodeAppTests** target.
9. Press **⌘R** to build.

---

## 🔧 How It Works

### QR Generation Pipeline (`QRCodeGenerator.swift`)

```
User types "https://example.com"
        │
        ▼
String → UTF-8 Data          // text.data(using: .utf8)
        │
        ▼
CIFilter.qrCodeGenerator()   // Apple's built-in QR filter
  .message        = data
  .correctionLevel = "M"     // L / M / Q / H
        │
        ▼
CIImage (tiny ~25×25 px)    // the raw QR pattern
        │
        ▼
CGAffineTransform(scale×10)  // scale up so it's crisp & scannable
        │
        ▼
CIContext.createCGImage()    // render to CGImage
        │
        ▼
UIImage(cgImage:)            // wrap for SwiftUI
        │
        ▼
CIPalette colour remap      // foreground/background tinting
        │
        ▼
Published in AppViewModel    // SwiftUI redraws automatically
```

### Key Concepts

- **`CIFilter.qrCodeGenerator`** — Apple ships this filter in CoreImage.
  It does all the Reed–Solomon error-correction math for you.
- **`CIPalette`** — A CoreImage filter that maps the darkest pixel
  (QR dots) to a foreground colour and the lightest (background) to
  a background colour. More reliable than manual blend-mode compositing.
- **`ShareLink`** — iOS 16+ API that wraps the native share sheet.
  Pass a `UIImage` and the system handles Photos, AirDrop, Messages, etc.
- **`@Published` in `AppViewModel`** — When state changes, SwiftUI
  automatically re-renders the relevant views. No manual refresh needed.
- **`PropertyListEncoder` / `FileManager`** — History is persisted to the
  app's sandbox Documents directory as a property list (`.plist`).

---

## 🧪 Running Tests

In Xcode:
- **Product → Test** (⌘U) to run all unit tests.
- Tests cover: basic generation, empty input, all correction levels,
  all size variants, PNG round-trip, and custom colours.

---

## 📱 Testing on a Real iPhone

1. In Xcode, go to **Product → Destination** and select your iPhone
   (or **More Devices** to register it).
2. You'll need a **free Apple Developer account**
   (just sign in with your Apple ID — no $99/year needed for personal testing).
3. Set **Signing & Capabilities** in the project settings:
   - **Team**: Your free Apple ID
   - **Bundle Identifier**: `com.YOURNAME.QRGenerator` (must be unique)
   - In `project.yml`, set `DEVELOPMENT_TEAM` to your team ID and
     `CODE_SIGNING_ALLOWED: "YES"` before regenerating.
4. Press **⌘R** — Xcode will build and install the app on your phone.

> **Tip**: With a free account you can run the app for 7 days before
> you need to re-sign. For development that's usually fine.

---

## 🎨 Customisation Ideas

The codebase is structured so these are easy to add:

- **Logo in the centre** — composite a small `UIImage` onto the QR
  centre pixel (requires correction level H).
- **Save directly to Photos** — add a `PHPhotoLibrary` call.
- **Wi-Fi / vCard / URL presets** — add quick-paste buttons that
  fill the text field with a formatted string.
- **Scan to fill** — use `AVCaptureSession` to scan a QR and
  pre-fill the input.
- **Export as PDF** — wrap the `UIImage` in a `PDFDocument` export.

---

## 📝 Requirements

- **Xcode 15+**
- **iOS 16+** (for `ShareLink`, `NavigationStack`, `axis:` TextField, `ColorPicker`)
- **Swift 5.9+**
- **XcodeGen** (optional, for automated project generation)

No external dependencies. No server. No network. Just CoreImage.

---

## ⚠️ Before App Store Submission

- Add a real **App Icon** (1024×1024 PNG) to `Assets.xcassets/AppIcon.appiconset/`.
- Add a `PrivacyInfo.xcprivacy` file if Apple requires one for your
  app category (not needed for simulator / personal use).
- Set a proper **Development Team** and **Bundle Identifier** in
  `project.yml` before signing.
