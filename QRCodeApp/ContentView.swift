//  ContentView.swift
//  QRCodeApp
//
//  Root view. Hosts the tab bar that switches between
//  the Generate screen and the History screen.
//  Each tab is wrapped in its own NavigationStack so that
//  navigation titles, toolbars, and sheets work correctly.

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var viewModel: AppViewModel

    var body: some View {
        TabView {
            NavigationStack {
                GenerateView()
            }
            .tabItem {
                Label("Generate", systemImage: "qrcode")
            }

            NavigationStack {
                HistoryView()
            }
            .tabItem {
                Label("History", systemImage: "clock.arrow.circlepath")
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppViewModel())
}
