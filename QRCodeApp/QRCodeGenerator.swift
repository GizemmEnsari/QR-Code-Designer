//  QRCodeGenerator.swift
//  QRCodeApp
//
//  Encapsulates all CoreImage QR-code logic.
//
//  Pipeline:
//    1. Convert the input string to UTF-8 Data.
//    2. Feed it into CIFilter.qrCodeGenerator (the tiny ~25×25 pixel pattern).
//    3. Set the correction level (L / M / Q / H).
//    4. Add a white quiet zone (≥ 4 modules on each side) — required by the
//       QR spec so scanners can reliably detect the edges.
//    5. Scale the padded pattern up so it is crisp and scannable.
//    6. Optionally tint with custom colours using CIPalette filter.
//    7. Render the CIImage → CGImage → UIImage via a shared CIContext.
//
//  Everything happens on-device. No network, no server.

import CoreImage
import UIKit

// MARK: - Colour helpers

extension UIColor {
    /// RGBA components as `[Double]` — suitable for `Codable` serialisation.
    var rgbaComponents: [Double] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        return [Double(r), Double(g), Double(b), Double(a)]
    }

    static func fromRGBA(_ components: [Double]) -> UIColor {
        guard components.count == 4 else { return .black }
        return UIColor(
            red:   CGFloat(components[0]),
            green: CGFloat(components[1]),
            blue:  CGFloat(components[2]),
            alpha: CGFloat(components[3])
        )
    }
}

// MARK: - Configuration

/// Correction level chosen by the user.
/// Higher level = more damage-resistant but denser (more dots) QR code.
enum CorrectionLevel: String, CaseIterable, Identifiable, Codable {
    case low      = "L" //  7%  error correction
    case medium   = "M" // 15%  (default)
    case quartile = "Q" // 25%
    case high     = "H" // 30%

    var id: String { rawValue }

    var label: String {
        switch self {
        case .low:      return "Low  (7%)"
        case .medium:   return "Medium (15%)"
        case .quartile: return "Quartile (25%)"
        case .high:     return "High (30%)"
        }
    }
}

/// User-chosen size multiplier.
enum QRSize: String, CaseIterable, Identifiable, Codable {
    case small   = "S"
    case medium  = "M"
    case large   = "L"
    case xLarge  = "XL"

    var id: String { rawValue }

    /// Scale factor applied to the raw QR pattern.
    var scale: CGFloat {
        switch self {
        case .small:  return 8
        case .medium: return 12
        case .large:  return 20
        case .xLarge: return 32
        }
    }

    var label: String {
        switch self {
        case .small:  return "Small"
        case .medium: return "Medium"
        case .large:  return "Large"
        case .xLarge: return "X-Large"
        }
    }
}

/// A fully resolved set of options passed into the generator.
///
/// Conforms to `Codable` and `Equatable` with custom implementations
/// because `UIColor` conforms to neither.
struct QRCodeOptions: Codable, Equatable {
    var correctionLevel: CorrectionLevel = .medium
    var size: QRSize = .medium
    /// When `true` the custom colours are applied via `CIPalette`.
    var useCustomColors: Bool = false
    /// Foreground (dot) colour. Defaults to black.
    var foregroundColor: UIColor = .black
    /// Background colour. Defaults to white.
    var backgroundColor: UIColor = .white

    // MARK: Initialisers

    init() {}

    // MARK: Codable (custom — UIColor is not Codable)

    private enum Keys: String, CodingKey {
        case correctionLevel, size, useCustomColors, fg, bg
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        correctionLevel = try c.decodeIfPresent(CorrectionLevel.self,
                                                forKey: .correctionLevel) ?? .medium
        size = try c.decodeIfPresent(QRSize.self, forKey: .size) ?? .medium
        useCustomColors = try c.decodeIfPresent(Bool.self,
                                                forKey: .useCustomColors) ?? false
        if let fg = try? c.decode([Double].self, forKey: .fg) {
            foregroundColor = UIColor.fromRGBA(fg)
        }
        if let bg = try? c.decode([Double].self, forKey: .bg) {
            backgroundColor = UIColor.fromRGBA(bg)
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(correctionLevel,   forKey: .correctionLevel)
        try c.encode(size,              forKey: .size)
        try c.encode(useCustomColors,   forKey: .useCustomColors)
        try c.encode(foregroundColor.rgbaComponents, forKey: .fg)
        try c.encode(backgroundColor.rgbaComponents, forKey: .bg)
    }

    // MARK: Equatable (custom — UIColor does not conform to Equatable)

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.correctionLevel == rhs.correctionLevel
        && lhs.size == rhs.size
        && lhs.useCustomColors == rhs.useCustomColors
        && lhs.foregroundColor.rgbaComponents == rhs.foregroundColor.rgbaComponents
        && lhs.backgroundColor.rgbaComponents == rhs.backgroundColor.rgbaComponents
    }
}

// MARK: - Generator

/// Stateless utility. One shared `CIContext` is reused for every call
/// so we avoid re-creating the GPU / CPU rendering context.
enum QRCodeGenerator {

    private static let context = CIContext()

    /// Number of quiet-zone modules added on each side of the QR pattern.
    /// The QR Code specification (ISO/IEC 18004) recommends a minimum of 4.
    static let quietZoneModules: CGFloat = 4.0

    // MARK: Public API

    /// Generate a QR-code `UIImage` from a string.
    static func generate(from text: String,
                         options: QRCodeOptions = QRCodeOptions()) -> UIImage? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        guard let data = trimmed.data(using: .utf8) else { return nil }

        guard let filter = CIFilter(name: "CIQRCodeGenerator") else { return nil }
        filter.setValue(data, forKey: "InputMessage")
        filter.setValue(options.correctionLevel.rawValue, forKey: "InputCorrectionLevel")

        guard let rawCIImage = filter.outputImage else { return nil }

        // 1. Add a white quiet zone around the raw QR pattern.
        //    Without this, scanners may fail to detect the edge.
        let quietZone = quietZoneModules
        let paddedExtent = rawCIImage.extent.insetBy(
            dx: -quietZone,
            dy: -quietZone
        )
        let white = CIImage(
            color: CIColor(red: 1, green: 1, blue: 1, alpha: 1)
        ).cropped(to: paddedExtent)
        let padded = rawCIImage.composited(over: white)

        // 2. Scale up so the QR is crisp and scannable.
        let scaled = padded.transformed(by: CGAffineTransform(
            scaleX: options.size.scale,
            y:      options.size.scale
        ))

        // 3. Render the black-on-white QR to a CGImage first.
        guard let baseCG = context.createCGImage(scaled, from: scaled.extent)
        else { return nil }

        // 4. Optionally recolour the dots/background with direct pixel
        //    manipulation. The previous `CIPalette` approach is unreliable:
        //    its `outputImage` can be nil on the simulator (and some devices),
        //    in which case it silently returned the uncoloured black image —
        //    the reason "colours don't work". Pixel manipulation is
        //    deterministic and identical on device and simulator.
        let finalCG: CGImage
        if options.useCustomColors {
            finalCG = recolor(baseCG,
                              foreground: options.foregroundColor,
                              background: options.backgroundColor)
        } else {
            finalCG = baseCG
        }

        return UIImage(cgImage: finalCG)
    }

    // MARK: Colour Tinting

    /// Recolour a rendered black-on-white QR image so the dots use `foreground`
    /// and the empty space uses `background`.
    ///
    /// Done with direct pixel manipulation rather than the `CIPalette` filter,
    /// because `CIPalette`'s `outputImage` can be `nil` on the simulator (and
    /// some devices) — in which case it silently returns the original black image
    /// and the user sees "colours don't work". Pixel manipulation is
    /// deterministic and behaves identically on device and simulator.
    ///
    /// Anti-aliased dot edges are preserved by blending between the background and
    /// foreground colours according to each pixel's darkness ("coverage").
    private static func recolor(
        _ image: CGImage,
        foreground: UIColor,
        background: UIColor
    ) -> CGImage {
        let width = image.width
        let height = image.height
        guard width > 0, height > 0 else { return image }
        let fg = foreground.rgbaComponents
        let bg = background.rgbaComponents
        guard fg.count == 4, bg.count == 4 else { return image }

        // Render the source (black-on-white) into a known RGBA8 buffer.
        var src = [UInt8](repeating: 0, count: width * height * 4)
        guard let srcCtx = CGContext(
            data: &src, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        srcCtx.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Recolour each pixel: white (coverage 0) -> background,
        // black (coverage 1) -> foreground, with edges blended.
        var dst = [UInt8](repeating: 0, count: width * height * 4)
        for i in stride(from: 0, to: src.count, by: 4) {
            let r = Double(src[i]) / 255.0
            let g = Double(src[i + 1]) / 255.0
            let b = Double(src[i + 2]) / 255.0
            // Darkness = how much of this pixel belongs to a dot. White -> 0, black -> 1.
            var coverage = 1.0 - (0.299 * r + 0.587 * g + 0.114 * b)
            coverage = coverage < 0 ? 0 : (coverage > 1 ? 1 : coverage)
            dst[i]     = clamp255(bg[0] + (fg[0] - bg[0]) * coverage)
            dst[i + 1] = clamp255(bg[1] + (fg[1] - bg[1]) * coverage)
            dst[i + 2] = clamp255(bg[2] + (fg[2] - bg[2]) * coverage)
            dst[i + 3] = 255 // fully opaque
        }

        guard let dstCtx = CGContext(
            data: &dst, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return image }
        return dstCtx.makeImage() ?? image
    }

    /// Clamp a 0…1 float to a 0…255 `UInt8` byte.
    private static func clamp255(_ v: Double) -> UInt8 {
        let x = v < 0 ? 0 : (v > 1 ? 1 : v)
        return UInt8((x * 255).rounded())
    }

    // MARK: Data helpers

    /// Returns the raw `Data` (PNG) of a generated QR image.
    static func pngData(from text: String,
                        options: QRCodeOptions = QRCodeOptions()) -> Data? {
        generate(from: text, options: options)?.pngData()
    }

    /// Reconstruct a `UIImage` from stored PNG data (used by History).
    static func image(from data: Data) -> UIImage? {
        UIImage(data: data)
    }
}

