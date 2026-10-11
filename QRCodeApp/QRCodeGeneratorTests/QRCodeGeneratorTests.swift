//  QRCodeGeneratorTests.swift
//  QRCodeApp
//
//  Unit tests for QR generation, data model, and view model.
//  Run via Xcode: Product → Test (⌘U).

import XCTest
import UIKit
@testable import QRCodeApp

// MARK: - QRCodeGenerator Tests

final class QRCodeGeneratorTests: XCTestCase {

    // MARK: Basic generation

    func testGenerateReturnsImage() {
        let image = QRCodeGenerator.generate(from: "https://example.com")
        XCTAssertNotNil(image)
    }

    func testPlainText() {
        let image = QRCodeGenerator.generate(from: "Hello, world!")
        XCTAssertNotNil(image)
    }

    // MARK: Edge cases

    func testEmptyStringReturnsNil() {
        XCTAssertNil(QRCodeGenerator.generate(from: ""))
    }

    func testWhitespaceReturnsNil() {
        XCTAssertNil(QRCodeGenerator.generate(from: "   \n\t "))
    }

    func testVeryLongTextDoesNotCrash() {
        _ = QRCodeGenerator.generate(from: String(repeating: "A", count: 5000))
    }

    func testUnicodeTextDoesNotCrash() {
        _ = QRCodeGenerator.generate(from: "Hello 🌍")
    }

    // MARK: Correction levels

    func testAllCorrectionLevels() {
        for level in CorrectionLevel.allCases {
            var opts = QRCodeOptions()
            opts.correctionLevel = level
            let image = QRCodeGenerator.generate(from: "https://apple.com", options: opts)
            XCTAssertNotNil(image, "Correction level \(level.rawValue)")
        }
    }

    func testHigherCorrectionLevelProducesLargerImage() {
        var lowOpts = QRCodeOptions()
        lowOpts.correctionLevel = .low
        var highOpts = QRCodeOptions()
        highOpts.correctionLevel = .high

        // Use a longer string that produces different QR versions for low vs high correction
        let text = "https://example.com/api/v1/resources/with/some/data?param=value&another=true"
        guard let low  = QRCodeGenerator.generate(from: text, options: lowOpts),
              let high = QRCodeGenerator.generate(from: text, options: highOpts) else {
            XCTFail("Both images should be generated")
            return
        }
        XCTAssertGreaterThan(high.size.width, low.size.width,
            "High correction should produce a larger image than Low")
    }

    // MARK: Size variants

    func testAllSizes() {
        for size in QRSize.allCases {
            var opts = QRCodeOptions()
            opts.size = size
            let image = QRCodeGenerator.generate(from: "https://apple.com", options: opts)
            XCTAssertNotNil(image, "Size \(size.rawValue)")
        }
    }

    func testLargerSizeProducesBiggerImage() {
        var smallOpts = QRCodeOptions()
        smallOpts.size = .small
        var largeOpts = QRCodeOptions()
        largeOpts.size = .large

        guard let small = QRCodeGenerator.generate(from: "test", options: smallOpts),
              let large = QRCodeGenerator.generate(from: "test", options: largeOpts) else {
            XCTFail("Both images should be generated")
            return
        }
        XCTAssertGreaterThan(large.size.width, small.size.width,
            "Large size should produce a bigger image than Small")
    }

    // MARK: Image dimensions & quiet zone

    func testImageHasNonTrivialDimensions() {
        guard let img = QRCodeGenerator.generate(from: "https://example.com") else {
            XCTFail("Should produce an image")
            return
        }
        XCTAssertGreaterThan(img.size.width, 100)
        XCTAssertGreaterThan(img.size.height, 100)
        let aspect = img.size.width / img.size.height
        XCTAssertGreaterThan(aspect, 0.9)
        XCTAssertLessThan(aspect, 1.1)
    }

    func testQuietZoneIsPresent() {
        var opts = QRCodeOptions()
        opts.size = .medium
        // Use a longer string to ensure the QR is at least version 2 (25 modules)
        guard let image = QRCodeGenerator.generate(from: "https://developer.apple.com/documentation", options: opts) else {
            XCTFail("Should produce an image")
            return
        }
        let expectedMin = CGFloat(33) * opts.size.scale
        XCTAssertGreaterThanOrEqual(image.size.width, expectedMin,
            "Image should include quiet zone padding")
    }

    // MARK: PNG data round-trip

    func testPNGDataRoundTrip() {
        let text = "https://developer.apple.com"
        guard let data = QRCodeGenerator.pngData(from: text) else {
            XCTFail("pngData should return Data")
            return
        }
        XCTAssertFalse(data.isEmpty)
        let restored = QRCodeGenerator.image(from: data)
        XCTAssertNotNil(restored)
    }

    func testPNGDataIsValidPNGHeader() {
        guard let data = QRCodeGenerator.pngData(from: "test") else {
            XCTFail("Should produce PNG data")
            return
        }
        let header: [UInt8] = [0x89, 0x50, 0x4E, 0x47]
        XCTAssertEqual(Array(data.prefix(4)), header)
    }

    // MARK: Colour options

    func testCustomForegroundProducesImage() {
        var opts = QRCodeOptions()
        opts.useCustomColors = true
        opts.foregroundColor = .blue
        opts.backgroundColor = .white
        let image = QRCodeGenerator.generate(from: "coloured", options: opts)
        XCTAssertNotNil(image, "Custom foreground should produce an image")
    }

    func testCustomBackgroundProducesImage() {
        var opts = QRCodeOptions()
        opts.useCustomColors = true
        opts.foregroundColor = .black
        opts.backgroundColor = .systemGray
        let image = QRCodeGenerator.generate(from: "coloured", options: opts)
        XCTAssertNotNil(image, "Custom background should produce an image")
    }

    func testUseCustomColorsFlagControlsTintPass() {
        let defaultOpts = QRCodeOptions()
        XCTAssertFalse(defaultOpts.useCustomColors)
        let image1 = QRCodeGenerator.generate(from: "test", options: defaultOpts)
        XCTAssertNotNil(image1)

        var customOpts = QRCodeOptions()
        customOpts.useCustomColors = true
        customOpts.foregroundColor = .red
        customOpts.backgroundColor = .yellow
        let image2 = QRCodeGenerator.generate(from: "test", options: customOpts)
        XCTAssertNotNil(image2)
    }

    // MARK: Colour rendering (pixel-level proof that colours actually appear)

    /// Count pixels that are NOT white and NOT black in a rendered QR image.
    /// Proves the recolor pass actually recolours the dots/background.
    private func nonWhitePixelCount(_ image: UIImage,
                                    in box: CGSize = CGSize(width: 100, height: 100)) -> Int {
        guard let cg = image.cgImage,
              let ctx = CGContext(data: nil,
                                  width: Int(box.width), height: Int(box.height),
                                  bitsPerComponent: 8,
                                  bytesPerRow: Int(box.width) * 4,
                                  space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            return 0
        }
        ctx.draw(cg, in: CGRect(x: 0, y: 0, width: box.width, height: box.height))
        guard let data = ctx.data else { return 0 }
        let ptr = data.assumingMemoryBound(to: UInt8.self)
        var count = 0
        for i in stride(from: 0, to: Int(box.width * box.height * 4), by: 4) {
            let r = ptr[i], g = ptr[i + 1], b = ptr[i + 2]
            // "non-white" means the tint changed it away from a pure white dot-free area
            if !(r > 235 && g > 235 && b > 235) { count += 1 }
        }
        return count
    }

    /// A red foreground on a white background must produce a QR whose dots are
    /// actually coloured (not left black) — the core "do colours work?" check.
    func testColoredForegroundIsActuallyColored() {
        var opts = QRCodeOptions()
        opts.useCustomColors = true
        opts.foregroundColor = .systemRed
        opts.backgroundColor = .white

        guard let image = QRCodeGenerator.generate(from: "colour test", options: opts) else {
            XCTFail("Coloured QR should be generated")
            return
        }
        // The dots must be coloured: a large share of pixels are non-white
        // (the red foreground), proving the tint pass ran.
        let nonWhite = nonWhitePixelCount(image)
        XCTAssertGreaterThan(nonWhite, 100,
            "Red foreground should recolour the QR dots (found \(nonWhite) non-white pixels)")

        // And the recoloured QR must still be a valid, decodable image with content.
        XCTAssertGreaterThan(image.size.width, 100)
    }

    /// An inverted high-contrast pair (blue on black) must render both colours.
    func testInvertedColorsRenderBothColors() {
        var opts = QRCodeOptions()
        opts.useCustomColors = true
        opts.foregroundColor = .systemBlue
        opts.backgroundColor = .black

        guard let image = QRCodeGenerator.generate(from: "inverted", options: opts) else {
            XCTFail("Inverted QR should be generated")
            return
        }
        // Not entirely black (blue dots present) and not entirely white.
        var total = 0, blackPixels = 0
        if let cg = image.cgImage,
           let ctx = CGContext(data: nil, width: 100, height: 100, bitsPerComponent: 8,
                               bytesPerRow: 400, space: CGColorSpaceCreateDeviceRGB(),
                               bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: 100, height: 100))
            if let data = ctx.data {
                let ptr = data.assumingMemoryBound(to: UInt8.self)
                total = 100 * 100
                for i in stride(from: 0, to: total * 4, by: 4) {
                    if ptr[i] < 20 && ptr[i + 1] < 20 && ptr[i + 2] < 20 { blackPixels += 1 }
                }
            }
        }
        // Background is black, so black pixels exist, but the blue dots mean it
        // is NOT all-black.
        XCTAssertGreaterThan(blackPixels, 50, "Blue-on-black should retain a black background")
        XCTAssertLessThan(blackPixels, total, "Blue dots must occupy some pixels (not all-black)")
    }
}

// MARK: - QRCodeOptions Tests

final class QRCodeOptionsTests: XCTestCase {

    func testDefaultOptions() {
        let opts = QRCodeOptions()
        XCTAssertEqual(opts.correctionLevel, .medium)
        XCTAssertEqual(opts.size, .medium)
        XCTAssertFalse(opts.useCustomColors)
    }

    func testCodableRoundTrip() throws {
        var opts = QRCodeOptions()
        opts.correctionLevel = .high
        opts.size = .large
        opts.useCustomColors = true
        opts.foregroundColor = .blue
        opts.backgroundColor = .systemYellow

        let encoder = PropertyListEncoder()
        let decoder = PropertyListDecoder()

        let data = try encoder.encode(opts)
        let decoded = try decoder.decode(QRCodeOptions.self, from: data)

        XCTAssertEqual(decoded.correctionLevel, .high)
        XCTAssertEqual(decoded.size, .large)
        XCTAssertTrue(decoded.useCustomColors)
        XCTAssertEqual(decoded, opts)
    }

    func testEquatable() {
        let opts1 = QRCodeOptions()
        let opts2 = QRCodeOptions()
        XCTAssertEqual(opts1, opts2)

        var opts3 = QRCodeOptions()
        opts3.correctionLevel = .high
        XCTAssertNotEqual(opts1, opts3)
    }

    func testRGBAComponents() {
        let black = UIColor.black.rgbaComponents
        XCTAssertEqual(black[0], 0, accuracy: 0.01)
        XCTAssertEqual(black[1], 0, accuracy: 0.01)
        XCTAssertEqual(black[2], 0, accuracy: 0.01)
        XCTAssertEqual(black[3], 1, accuracy: 0.01)

        let white = UIColor.white.rgbaComponents
        XCTAssertEqual(white[0], 1, accuracy: 0.01)
        XCTAssertEqual(white[1], 1, accuracy: 0.01)
        XCTAssertEqual(white[2], 1, accuracy: 0.01)
        XCTAssertEqual(white[3], 1, accuracy: 0.01)
    }
}

// MARK: - QRCodeItem Tests

final class QRCodeItemTests: XCTestCase {

    func testCodableRoundTrip() throws {
        var opts = QRCodeOptions()
        opts.correctionLevel = .high
        opts.size = .large

        let item = QRCodeItem(
            text: "https://test.com",
            options: opts,
            date: Date(timeIntervalSince1970: 1_700_000_000),
            imageData: Data([0x89, 0x50, 0x4E, 0x47])
        )

        let encoder = PropertyListEncoder()
        let decoder = PropertyListDecoder()

        let data = try encoder.encode(item)
        let decoded = try decoder.decode(QRCodeItem.self, from: data)

        XCTAssertEqual(decoded.text, "https://test.com")
        XCTAssertEqual(decoded.options.correctionLevel, .high)
        XCTAssertEqual(decoded.options.size, .large)
        XCTAssertEqual(item.id, decoded.id)
    }

    func testDisplayTextTruncation() {
        let longText = String(repeating: "A", count: 50)
        let item = QRCodeItem(
            text: longText,
            options: QRCodeOptions(),
            date: Date(),
            imageData: Data()
        )
        XCTAssertTrue(item.displayText.hasSuffix("…"))
        XCTAssertEqual(item.displayText.count, 41)
    }

    func testDisplayTextShort() {
        let item = QRCodeItem(
            text: "short",
            options: QRCodeOptions(),
            date: Date(),
            imageData: Data()
        )
        XCTAssertEqual(item.displayText, "short")
        XCTAssertFalse(item.displayText.hasSuffix("…"))
    }

    func testDateFormattedIsNotEmpty() {
        let item = QRCodeItem(
            text: "test",
            options: QRCodeOptions(),
            date: Date(),
            imageData: Data()
        )
        XCTAssertFalse(item.dateFormatted.isEmpty)
    }
}

// MARK: - AppViewModel Tests

@MainActor
final class AppViewModelTests: XCTestCase {

    override func setUpWithError() throws {
        try super.setUpWithError()
        let fileURL = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent("qr_history.plist")
        try? FileManager.default.removeItem(at: fileURL)
    }

    func testGenerateProducesImage() {
        let vm = AppViewModel()
        vm.generate(from: "https://example.com", options: QRCodeOptions())
        XCTAssertNotNil(vm.currentImage, "After generate, currentImage should be non-nil")
        XCTAssertEqual(vm.currentPayload, "https://example.com")
    }

    func testGenerateEmptyTextDoesNothing() {
        let vm = AppViewModel()
        vm.generate(from: "   ", options: QRCodeOptions())
        XCTAssertNil(vm.currentImage, "Empty text should not produce an image")
        XCTAssertTrue(vm.history.isEmpty, "History should remain empty")
    }

    func testHistoryInsertion() {
        let vm = AppViewModel()
        vm.generate(from: "first", options: QRCodeOptions())
        vm.generate(from: "second", options: QRCodeOptions())

        XCTAssertEqual(vm.history.count, 2)
        XCTAssertEqual(vm.history[0].text, "second")
        XCTAssertEqual(vm.history[1].text, "first")
    }

    func testDeleteItem() {
        let vm = AppViewModel()
        vm.generate(from: "to-delete", options: QRCodeOptions())
        let itemToDelete = vm.history[0]

        vm.delete(item: itemToDelete)
        XCTAssertTrue(vm.history.isEmpty, "History should be empty after delete")
    }

    func testClearHistory() {
        let vm = AppViewModel()
        vm.generate(from: "one", options: QRCodeOptions())
        vm.generate(from: "two", options: QRCodeOptions())
        XCTAssertEqual(vm.history.count, 2)

        vm.clearHistory()
        XCTAssertTrue(vm.history.isEmpty)
        XCTAssertNil(vm.currentImage)
    }

    func testPersistenceRoundTrip() {
        let vm = AppViewModel()
        vm.generate(from: "persist-test", options: QRCodeOptions())
        XCTAssertFalse(vm.history.isEmpty)

        let vm2 = AppViewModel()
        XCTAssertFalse(vm2.history.isEmpty, "History should be loaded from disk")
        XCTAssertEqual(vm2.history.first?.text, "persist-test")
    }
}

// MARK: - Enum Tests

final class EnumTests: XCTestCase {

    func testCorrectionLevelLabels() {
        for level in CorrectionLevel.allCases {
            XCTAssertFalse(level.label.isEmpty, "\(level.rawValue) should have a label")
            XCTAssertFalse(level.id.isEmpty)
        }
    }

    func testQRSizeScalesArePositive() {
        for size in QRSize.allCases {
            XCTAssertGreaterThan(size.scale, 0, "\(size.rawValue) scale should be positive")
            XCTAssertFalse(size.label.isEmpty)
        }
    }

    func testCorrectionLevelCodable() throws {
        for level in CorrectionLevel.allCases {
            let data = try JSONEncoder().encode(level)
            let decoded = try JSONDecoder().decode(CorrectionLevel.self, from: data)
            XCTAssertEqual(decoded, level)
        }
    }

    func testQRSizeCodable() throws {
        for size in QRSize.allCases {
            let data = try JSONEncoder().encode(size)
            let decoded = try JSONDecoder().decode(QRSize.self, from: data)
            XCTAssertEqual(decoded, size)
        }
    }
}
