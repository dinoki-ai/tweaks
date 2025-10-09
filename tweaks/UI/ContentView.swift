//
//  ContentView.swift
//  tweaks
//
//  Root container view and tab routing
//

import AppKit
import Carbon
import SwiftUI

struct ContentView: View {
  @StateObject private var settingsManager = SettingsManager.shared
  @ObservedObject private var permissionManager = PermissionManager.shared

  @State private var selectedTab = 0
  @State private var recordedKeyCode: UInt32 = UInt32(kVK_ANSI_T)
  @State private var recordedModifiers: UInt32 = UInt32(controlKey | optionKey)

  private func loadSavedShortcut() {
    let defaults = UserDefaults.standard
    if defaults.object(forKey: "HotkeyKeyCode") != nil {
      recordedKeyCode = UInt32(defaults.integer(forKey: "HotkeyKeyCode"))
    }
    if defaults.object(forKey: "HotkeyModifiers") != nil {
      recordedModifiers = UInt32(defaults.integer(forKey: "HotkeyModifiers"))
    }
  }

  var body: some View {
    ZStack {
      // Background
      FuturisticTheme.background
        .ignoresSafeArea()

      VStack(spacing: 0) {
        // Header
        HeaderView(
          permissionStatus: permissionManager.accessibilityStatus,
          selectedTab: $selectedTab
        )

        // Main Content
        ScrollView {
          VStack(spacing: 20) {
            switch selectedTab {
            case 0:
              MainView(
                recordedKeyCode: recordedKeyCode,
                recordedModifiers: recordedModifiers
              )
            case 1:
              AISettingsView()
            default:
              EmptyView()
            }
          }
          .padding(20)
        }
      }
    }
    .frame(width: 380, height: 500)
    .preferredColorScheme(.dark)
    .onAppear {
      loadSavedShortcut()
      Task {
        await settingsManager.fetchAvailableModels()
      }
    }
  }
}

#Preview {
  ContentView()
}
