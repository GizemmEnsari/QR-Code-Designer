//  QRCodeItem.swift
//  QRCodeApp
//
//  A single entry in the generation history.
//  Stored in `AppViewModel` for the session and optionally
//  persisted to disk via `PropertyListEncoder` + `FileManager`.
//
//  NOTE: `Equatable` is intentionally NOT declared here because
//  `QRCodeOptions` contains `UIColor`, which does not conform to
//  Swift's `Equatable` protocol. `Identifiable` alone is sufficient
//  for `ForEach` and `List` usage.

import UIKit
import Foundation

struct QRCodeItem: Identifiable, Codable {
    var id: UUID = UUID()
    let text: String          // original payload the user typed
    let options: QRCodeOptions // settings used at generation time
    let date: Date            // when it was generated
    let imageData: Data       // PNG bytes so we can redraw without re-generating

    var previewImage: UIImage? { UIImage(data: imageData) }

    // Human-friendly snippet for the history list.
    var displayText: String {
        if text.count > 40 {
            return String(text.prefix(40)) + "…"
        }
        return text
    }

    var dateFormatted: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
