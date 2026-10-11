//  AppViewModel.swift
//  QRCodeApp
//
//  Holds the shared app state:
//   • the list of generated QR codes (history)
//   • the currently selected QR image (for the Generate tab)
//   • persistence to / from disk
//
//  This is intentionally small — all the heavy lifting lives in
//  `QRCodeGenerator`.

import SwiftUI
import Combine

@MainActor
final class AppViewModel: ObservableObject {

    // MARK: Published state

    /// The QR image currently shown on the Generate screen.
    @Published var currentImage: UIImage?

    /// The payload that produced `currentImage` (used by the ShareLink title).
    @Published var currentPayload: String = ""

    /// Every QR generated this session (most-recent first).
    @Published var history: [QRCodeItem] = []

    // MARK: Persistence

    private let fileName = "qr_history.plist"
    private var fileURL: URL {
        FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)
            .first!
            .appendingPathComponent(fileName)
    }

    // MARK: Init

    init() {
        loadHistory()
    }

    // MARK: Actions

    /// Called when the user taps "Generate".
    /// Produces the QR image and prepends it to the history list.
    func generate(from text: String, options: QRCodeOptions) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            currentImage = nil
            return
        }

        // CoreImage generation is fast, but keep it off the main-thread hot path
        // for very large payloads. For a phone app this is fine on the main actor.
        if let image = QRCodeGenerator.generate(from: text, options: options) {
            currentImage   = image
            currentPayload = text

            // Snapshot the PNG bytes for history + sharing.
            if let data = image.pngData() {
                let item = QRCodeItem(
                    text: text,
                    options: options,
                    date: Date(),
                    imageData: data
                )
                history.insert(item, at: 0)
                saveHistory()
            }
        } else {
            // Payload too large or encoding failed.
            currentImage = nil
        }
    }

    /// Delete a single history entry.
    func delete(item: QRCodeItem) {
        history.removeAll { $0.id == item.id }
        saveHistory()
    }

    /// Clear the entire history.
    func clearHistory() {
        history.removeAll()
        currentImage = nil
        saveHistory()
    }

    // MARK: Persistence helpers

    private func saveHistory() {
        guard let data = try? PropertyListEncoder().encode(history) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private func loadHistory() {
        guard let data = try? Data(contentsOf: fileURL) else { return }
        if let items = try? PropertyListDecoder().decode([QRCodeItem].self, from: data) {
            history = items
        }
    }
}
