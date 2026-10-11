//  GenerateView.swift
//  QRCodeApp
//
//  The main screen: a text field, generation options, a "Generate" button,
//  the resulting QR code, and a ShareLink that opens the iOS share sheet.

import SwiftUI

struct GenerateView: View {

    @EnvironmentObject var viewModel: AppViewModel

    // MARK: Local @State — the user's current input & chosen options.

    @State private var inputText: String = ""

    @State private var correctionLevel: CorrectionLevel = .medium
    @State private var qrSize: QRSize = .medium

    /// Preset colours shared by both pickers.
    /// `static let` guarantees the same array instance every render,
    /// so index-based selection avoids the UIColor reference-equality bug.
    private static let presetColors: [UIColor] = [
        .black, .white, .systemRed, .systemOrange,
        .systemYellow, .systemGreen, .systemBlue,
        .systemPurple, .systemPink, .systemTeal,
    ]

    /// Index-based selection — `Int` value type avoids UIColor identity issues.
    @State private var foregroundIndex: Int = 0   // .black
    @State private var backgroundIndex: Int = 1    // .white
    @State private var useCustomColors = false
    /// Track the last generated text so we can re-apply colours without
    /// overwriting a user's new input.
    @State private var lastGeneratedText: String = ""

    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showFullScreen = false
    @State private var shareItems: [Any] = []
    @State private var showShare = false

    // MARK: Derived options

    private var currentOptions: QRCodeOptions {
        var opts = QRCodeOptions()
        opts.correctionLevel = correctionLevel
        opts.size = qrSize
        if useCustomColors {
            opts.useCustomColors = true
            opts.foregroundColor = GenerateView.presetColors[foregroundIndex]
            opts.backgroundColor = GenerateView.presetColors[backgroundIndex]
        }
        return opts
    }

    // MARK: - Contrast (scannability)

    /// WCAG relative luminance (0–1) of a colour.
    private static func luminance(of color: UIColor) -> Double {
        var r = CGFloat(0), g = CGFloat(0), b = CGFloat(0), a = CGFloat(0)
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        func lin(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        let R = lin(Double(r)), G = lin(Double(g)), B = lin(Double(b))
        return (0.2126 * R + 0.7152 * G + 0.0722 * B) * Double(a)
    }

    /// Contrast ratio (1–21) between two preset colours.
    private static func contrastRatio(fg: UIColor, bg: UIColor) -> Double {
        let l1 = luminance(of: fg), l2 = luminance(of: bg)
        let hi = max(l1, l2) + 0.05
        let lo = min(l1, l2) + 0.05
        return hi / lo
    }

    /// Contrast of the currently selected foreground/background pair.
    private var currentContrast: Double {
        Self.contrastRatio(
            fg: GenerateView.presetColors[foregroundIndex],
            bg: GenerateView.presetColors[backgroundIndex]
        )
    }

    /// Scanners need a strong luminance difference; below ~3:1 the code is at
    /// risk of not scanning, so we warn the user.
    private var colorsScannable: Bool { currentContrast >= 3.0 }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                inputSection
                optionsSection
                generateButton

                if let image = viewModel.currentImage {
                    qrDisplay(image: image)
                    shareSection(image: image)
                } else {
                    placeholder
                }
            }
            .padding()
            .padding(.bottom, 32)
        }
        .background(TapToDismissKeyboard())
        .navigationTitle("Generate")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Unable to generate", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .fullScreenCover(isPresented: $showFullScreen) {
            if let image = viewModel.currentImage {
                FullScreenQRView(image: image) {
                    showFullScreen = false
                }
            }
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: shareItems)
        }
        // Live-update the QR the instant a colour changes — even before the user
        // presses "Generate" (auto-generates from the current text so the colour
        // change is always visible).
        .onChange(of: foregroundIndex) { _ in applyColorsLive() }
        .onChange(of: backgroundIndex) { _ in applyColorsLive() }
        .onChange(of: useCustomColors) { enabled in
            if enabled {
                // First time on: if the user is still on the no-op black-on-white
                // default, nudge the foreground to a clearly visible colour so
                // they can immediately *see* that custom colours work.
                if foregroundIndex == 0 && backgroundIndex == 1 {
                    foregroundIndex = 2   // systemRed — high contrast on white
                }
                applyColorsLive()
            } else {
                // Toggling off reverts to a normal black-on-white QR.
                if !lastGeneratedText.isEmpty {
                    var opts = QRCodeOptions()
                    opts.correctionLevel = correctionLevel
                    opts.size = qrSize
                    viewModel.generate(from: lastGeneratedText, options: opts)
                }
            }
        }
    }

    // MARK: Sections

    private var inputSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Enter Text or URL")
                .font(.headline)
            Textifier(text: $inputText, placeholder: "https://example.com  or  any text")
        }
    }

    private var optionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Options")
                .font(.headline)

            // Correction level
            VStack(alignment: .leading, spacing: 6) {
                Text("Correction")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(CorrectionLevel.allCases) { level in
                        Button {
                            correctionLevel = level
                        } label: {
                            Text(level.label)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    correctionLevel == level
                                        ? AnyShapeStyle(Color.accentColor)
                                        : AnyShapeStyle(Color(uiColor: .systemGray5))
                                )
                                .foregroundColor(correctionLevel == level ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Size
            VStack(alignment: .leading, spacing: 6) {
                Text("Size")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                HStack(spacing: 8) {
                    ForEach(QRSize.allCases) { size in
                        Button {
                            qrSize = size
                        } label: {
                            Text(size.label)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    qrSize == size
                                        ? AnyShapeStyle(Color.accentColor)
                                        : AnyShapeStyle(Color(uiColor: .systemGray5))
                                )
                                .foregroundColor(qrSize == size ? .white : .primary)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            // Custom colours — visible card with border
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Custom Colours")
                        .font(.subheadline)
                    Spacer()
                    Toggle("", isOn: $useCustomColors)
                        .labelsHidden()
                        .scaleEffect(0.8)
                }
                .padding(12)
                .background(Color(uiColor: .systemGray6))
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color(uiColor: .systemGray3), lineWidth: 1.5)
                )

                if useCustomColors {
                    colorPickerRow(label: "Foreground", index: $foregroundIndex)
                        .padding(12)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(uiColor: .systemGray3), lineWidth: 1.5)
                        )
                    colorPickerRow(label: "Background", index: $backgroundIndex)
                        .padding(12)
                        .background(Color(uiColor: .systemBackground))
                        .cornerRadius(10)
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(uiColor: .systemGray3), lineWidth: 1.5)
                        )

                    // Live scannability feedback — the fix for "colours don't
                    // look right / won't scan".
                    if !colorsScannable {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("Low contrast — this QR may not scan. Use a darker foreground or a lighter background.")
                                .font(.caption)
                                .foregroundColor(.orange)
                            Spacer(minLength: 0)
                            Button("Fix") {
                                foregroundIndex = 0   // black
                                backgroundIndex = 1    // white
                            }
                            .font(.caption).bold()
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(10)
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Colours applied")
                                .font(.caption)
                                .foregroundColor(.green)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.green.opacity(0.10))
                        .cornerRadius(10)
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(uiColor: .systemGroupedBackground))
        )
    }

    /// A row: label on the left, a horizontal strip of colour circles on the right.
    private func colorPickerRow(label: String, index: Binding<Int>) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            ColorPickerCircle(
                colors: GenerateView.presetColors,
                selectedIndex: index
            )
        }
    }

    private var generateButton: some View {
        Button(action: generate) {
            Text("Generate QR Code")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(12)
        }
        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        .opacity(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 0.5 : 1.0)
    }

    private func qrDisplay(image: UIImage) -> some View {
        VStack(spacing: 12) {
            Text("Your QR Code")
                .font(.headline)

            Image(uiImage: image)
                .interpolation(.none)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 280, maxHeight: 280)
                .padding(16)
                .background(Color.white)
                .cornerRadius(16)
                .shadow(radius: 4)
                .onTapGesture {
                    showFullScreen = true
                }

            Text("Tap to view full screen")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func shareSection(image: UIImage) -> some View {
        HStack(spacing: 12) {
            Button {
                shareItems = [image]
                showShare = true
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .frame(maxWidth: .infinity)

            Button {
                showFullScreen = true
            } label: {
                Label("Full Screen", systemImage: "arrow.up.left.and.arrow.down.right")
                    .font(.headline)
                    .padding()
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(12)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var placeholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "qrcode.viewfinder")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("Enter text and tap Generate")
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 40)
    }

    // MARK: Action

    private func generate() {
        let text = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        // Remember the payload so live colour changes can re-apply the current
        // options without overwriting anything the user is typing.
        lastGeneratedText = text

        viewModel.generate(from: text, options: currentOptions)

        if viewModel.currentImage == nil {
            errorMessage = "The text may be too long or contain characters that can't be encoded. Try shorter text."
            showError = true
        }
    }

    /// Re-applies the current colour options to the QR the instant the user
    /// changes them, so colours update *live* — no separate "Generate" tap.
    ///
    /// Falls back to `inputText` when nothing has been generated yet, so even a
    /// first colour pick shows a result. This is the fix for "I can't see any
    /// colour change": the QR now updates on the first interaction.
    private func applyColorsLive() {
        let text = (lastGeneratedText.isEmpty ? inputText : lastGeneratedText)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        lastGeneratedText = text
        viewModel.generate(from: text, options: currentOptions)
    }
}

// MARK: - Text field wrapper

struct Textifier: View {
    @Binding var text: String
    var placeholder: String

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .lineLimit(3...6)
            .textFieldStyle(.roundedBorder)
            .autocapitalization(.none)
            .autocorrectionDisabled(true)
    }
}

// MARK: - Full-screen QR viewer

/// Presents the QR code on a dark background at maximum size so that
/// another device can scan it easily.
struct FullScreenQRView: View {
    let image: UIImage
    let onDismiss: () -> Void
    @State private var showShare = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: 320, maxHeight: 320)
                    .padding(20)
                    .background(Color.white)
                    .cornerRadius(20)
                    .shadow(radius: 8)

                Text("Point another camera here to scan")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))

                Button {
                    showShare = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.bottom, 8)

                Button("Done") { onDismiss() }
                    .font(.headline)
                    .foregroundColor(.white)
            }
            .padding()
        }
        .sheet(isPresented: $showShare) {
            ShareSheet(items: [image])
        }
    }
}


// MARK: - Color Picker Circle

/// A horizontal strip of tappable colour circles with a checkmark on the
/// selected one. Uses an Int index to avoid UIColor reference-equality bugs.
struct ColorPickerCircle: View {
    let colors: [UIColor]
    @Binding var selectedIndex: Int

    var body: some View {
        ScrollView(.horizontal, showsIndicators: true) {
            HStack(spacing: 10) {
                ForEach(Array(colors.indices), id: \.self) { i in
                    Button {
                        selectedIndex = i
                    } label: {
                        ZStack {
                            Circle()
                                .fill(Color(uiColor: colors[i]))
                                .frame(width: 30, height: 30)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            selectedIndex == i
                                                ? Color.accentColor
                                                : Color.gray.opacity(0.6),
                                            lineWidth: selectedIndex == i ? 3 : 1.5
                                        )
                                )

                            if selectedIndex == i {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundColor(shouldUseDarkCheck(for: colors[i]) ? .black : .white)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 4)
        }
    }

    /// Returns true when the checkmark should be dark (light background colour).
    private func shouldUseDarkCheck(for color: UIColor) -> Bool {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        let result = color.getRed(&r, green: &g, blue: &b, alpha: &a)
        if !result { return false }
        let luminance = 0.299 * r + 0.587 * g + 0.114 * b
        return luminance > 0.5
    }
}

// MARK: - Tap to Dismiss Keyboard

/// A transparent view that resigns the first responder (keyboard) on tap.
struct TapToDismissKeyboard: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = true
        let tap = UITapGestureRecognizer(target: context.coordinator,
                                       action: #selector(Coordinator.onTap))
        view.addGestureRecognizer(tap)
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject {
        @objc func onTap() {
            UIApplication.shared.sendAction(
                #selector(UIResponder.resignFirstResponder),
                to: nil, from: nil, for: nil
            )
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        GenerateView()
    }
    .environmentObject(AppViewModel())
}

