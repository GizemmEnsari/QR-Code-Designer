//  QRCodeApp.swift
//  QRCodeApp
//
//  Created: 2026
//  A native, on-device QR Code Generator built with SwiftUI + CoreImage.
//  No server, no network — everything runs locally on the iPhone.
//
//  How to run:
//    1. Open this folder in Xcode (drag into Xcode or File → New → Project).
//    2. Select the iPhone simulator or a connected device.
//    3. Press ⌘R to build and run.
//
//  Requires: Xcode 15+, iOS 16+ deployment target.

import SwiftUI

@main
struct QRCodeApp: App {
    // Shared state so history persists across tab switches within the session.
    @StateObject private var viewModel = AppViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .tint(.accentColor) // consistent accent across the app
        }
    }
}
