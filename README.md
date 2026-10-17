# QR Generator

A native offline QR code generator for iPhone built with SwiftUI and Apple CoreImage. No server. No database. No network calls. Everything runs on device.

## Features

- **Text and URL input**: type any text or paste a URL and CoreImage encodes it
- **Correction levels**: L, M, Q, H, where more correction means a denser but more damage resistant code
- **Size options**: small to X Large scale multipliers
- **Custom colours**: foreground and background colour pickers
- **Share and Save**: ShareLink opens the native iOS share sheet for Photos, AirDrop, Messages and more
- **History**: every generation is stored and can be re-shared or deleted
- **Dark mode**: fully supports system dark mode
- **Offline**: zero network requests, CoreImage does all the QR math locally

## Project Structure

```
QRCodeApp/
├── QRCodeApp.swift
├── ContentView.swift
├── GenerateView.swift
├── HistoryView.swift
├── QRCodeGenerator.swift
├── QRCodeItem.swift
├── AppViewModel.swift
└── Assets.xcassets/
```

## How It Works

```
User types text or URL
String to UTF8 Data
CIFilter.qrCodeGenerator()
CIImage
Scale up for crisp scanning
CIContext.createCGImage()
UIImage
Colour remap for foreground and background
Published in AppViewModel so SwiftUI redraws
```

- **CIFilter.qrCodeGenerator** handles all the Reed Solomon error correction math for you
- **ShareLink** is the iOS 16 API that wraps the native share sheet
- **Published in AppViewModel** means SwiftUI re-renders automatically when state changes
- **History** is saved locally using JSONEncoder and UserDefaults

## Customisation Ideas

- **Logo in the centre** by compositing a small UIImage onto the centre pixel, which needs correction level H
- **Save directly to Photos** by adding a PHPhotoLibrary call
- **Wi Fi, vCard and URL presets** as quick paste buttons that fill the text field
- **Scan to fill** with AVCaptureSession to scan a QR and pre fill the input
- **Export as PDF** by wrapping the UIImage in a PDFDocument export

## Requirements

- Xcode 15 or newer
- iOS 16 or newer
- Swift 5.9 or newer

No external dependencies. No server. No network. Just CoreImage.
