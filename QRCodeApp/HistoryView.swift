//  HistoryView.swift
//  QRCodeApp
//
//  A scrollable list of every QR code generated this session,
//  persisted to disk via AppViewModel.
//  Tap a row to preview & share; swipe to delete.

import SwiftUI

struct HistoryView: View {

    @EnvironmentObject var viewModel: AppViewModel

    @State private var selectedItem: QRCodeItem?
    @State private var showClearConfirm = false

    var body: some View {
        Group {
            if viewModel.history.isEmpty {
                emptyState
            } else {
                historyList
            }
        }
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !viewModel.history.isEmpty {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear", systemImage: "trash")
                    }
                }
            }
        }
        .confirmationDialog("Clear entire history?",
                            isPresented: $showClearConfirm,
                            titleVisibility: .visible) {
            Button("Clear All", role: .destructive) {
                viewModel.clearHistory()
            }
            Button("Cancel", role: .cancel) {}
        }
        .sheet(item: $selectedItem) { item in
            DetailSheet(item: item)
        }
    }

    // MARK: List

    private var historyList: some View {
        List {
            ForEach(viewModel.history) { item in
                HistoryRow(item: item)
                    .contentShape(Rectangle())
                    .onTapGesture { selectedItem = item }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            viewModel.delete(item: item)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "clock")
                .font(.system(size: 50))
                .foregroundColor(.secondary)
            Text("No QR codes yet")
                .foregroundColor(.secondary)
            Text("Generate one to see it here.")
                .font(.footnote)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}

// MARK: - Row

struct HistoryRow: View {
    let item: QRCodeItem

    var body: some View {
        HStack(spacing: 12) {
            if let image = item.previewImage {
                Image(uiImage: image)
                    .interpolation(.none)
                    .resizable()
                    .frame(width: 56, height: 56)
                    .background(Color.white)
                    .cornerRadius(6)
            } else {
                Image(systemName: "qrcode")
                    .frame(width: 56, height: 56)
                    .background(Color(.systemGroupedBackground))
                    .cornerRadius(6)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(item.displayText)
                    .lineLimit(2)
                    .font(.body)
                Text(item.dateFormatted)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail sheet

struct DetailSheet: View {
    @Environment(\.dismiss) var dismiss
    let item: QRCodeItem
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if let image = item.previewImage {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 280, maxHeight: 280)
                        .padding(16)
                        .background(Color.white)
                        .cornerRadius(16)
                }

                Text(item.text)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .textSelection(.enabled)
                    .padding(.horizontal)

                Button {
                    showShare = true
                } label: {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.accentColor)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("QR Code")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: [item.previewImage ?? UIImage()])
            }
        }
    }
}

// MARK: - Share sheet wrapper

/// Wraps `UIActivityViewController` so it can be presented from SwiftUI.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Preview

#Preview {
    NavigationStack {
        HistoryView()
    }
    .environmentObject(AppViewModel())
}
