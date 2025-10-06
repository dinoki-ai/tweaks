//
//  ContentView.swift
//  tweaks
//
//  Created by Terence on 10/5/25.
//

import SwiftUI
import AppKit
import Carbon

struct ContentView: View {
    @State private var selectedTab = 0
    @State private var recordingShortcut: Bool = false
    @State private var recordedKeyCode: UInt32 = UInt32(kVK_ANSI_T)
    @State private var recordedModifiers: UInt32 = UInt32(controlKey)
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var feedbackManager = HotkeyFeedbackManager.shared
    
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
        VStack(spacing: 0) {
            // Simple Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(.tint)
                Text("Tweaks")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                
                // Quick status indicator
                Image(systemName: permissionManager.accessibilityStatus.icon)
                    .foregroundColor(permissionManager.accessibilityStatus.color)
                    .imageScale(.large)
                    .help(permissionManager.accessibilityStatus.message)
            }
            .padding()
            
            Divider()
            
            // Tab selection
            Picker("", selection: $selectedTab) {
                Text("Main").tag(0)
                Text("Settings").tag(1)
                if DebugHelpers.isDebugBuild {
                    Text("Debug").tag(2)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
            .padding(.vertical, 8)
            
            // Tab content
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    switch selectedTab {
                    case 0:
                        MainTabView(recordedKeyCode: recordedKeyCode, recordedModifiers: recordedModifiers)
                    case 1:
                        SettingsTabView(
                            recordingShortcut: $recordingShortcut,
                            recordedKeyCode: $recordedKeyCode,
                            recordedModifiers: $recordedModifiers
                        )
                    case 2:
                        DebugTabView()
                    default:
                        EmptyView()
                    }
                }
                .padding()
            }
        }
        .frame(width: 300, height: 450)
        .onAppear {
            loadSavedShortcut()
        }
        .background(RecordingView(isRecording: $recordingShortcut) { keyCode, modifiers in
            recordedKeyCode = keyCode
            recordedModifiers = modifiers
            (NSApp.delegate as? AppDelegate)?.updateGlobalHotkey(keyCode: keyCode, modifiers: modifiers)
            feedbackManager.hotkeyTriggered() // Visual feedback when changed
        })
    }
}

// MARK: - Tab Views

struct MainTabView: View {
    let recordedKeyCode: UInt32
    let recordedModifiers: UInt32
    @ObservedObject private var permissionManager = PermissionManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Quick intro
            VStack(alignment: .leading, spacing: 8) {
                Label("Paste tweaked text", systemImage: "sparkles")
                    .font(.headline)
                
                Text("Press **\(shortcutDisplayString(keyCode: recordedKeyCode, modifiers: recordedModifiers))** to paste your clipboard text improved by Osaurus.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.1))
            .cornerRadius(8)
            
            // Permission status
            PermissionStatusView()
            
            // Hotkey testing
            if permissionManager.accessibilityStatus == .granted {
                HotkeyTestView()
            }
        }
    }
}

struct SettingsTabView: View {
    @Binding var recordingShortcut: Bool
    @Binding var recordedKeyCode: UInt32
    @Binding var recordedModifiers: UInt32
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hotkey customization
            VStack(alignment: .leading, spacing: 12) {
                Label("Global Hotkey", systemImage: "keyboard")
                    .font(.headline)
                
                HStack {
                    Text("Current:")
                        .foregroundColor(.secondary)
                    
                    Text(shortcutDisplayString(keyCode: recordedKeyCode, modifiers: recordedModifiers))
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(6)
                    
                    Spacer()
                    
                    Button(action: { recordingShortcut = true }) {
                        Text(recordingShortcut ? "Recording..." : "Change")
                            .foregroundColor(recordingShortcut ? .orange : .accentColor)
                    }
                    .buttonStyle(.bordered)
                }
                
                if recordingShortcut {
                    HStack {
                        Image(systemName: "keyboard")
                            .foregroundColor(.orange)
                        Text("Press your desired key combination...")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            // App behavior
            VStack(alignment: .leading, spacing: 12) {
                Label("Behavior", systemImage: "gearshape")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "menubar.rectangle")
                            .foregroundColor(.secondary)
                        Text("Lives in menu bar")
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "keyboard.fill")
                            .foregroundColor(.secondary)
                        Text("Global hotkey support")
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "face.smiling")
                            .foregroundColor(.secondary)
                        Text("Tweaks clipboard text using Osaurus")
                            .font(.subheadline)
                    }
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
            
            Spacer()
            
            // Quit button
            Button(action: { NSApp.terminate(nil) }) {
                HStack {
                    Image(systemName: "power")
                    Text("Quit Tweaks")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
    }
}

struct DebugTabView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            DebugPermissionHelper()
            
            // Additional debug info
            VStack(alignment: .leading, spacing: 8) {
                Label("Build Info", systemImage: "info.circle")
                    .font(.headline)
                
                VStack(alignment: .leading, spacing: 4) {
                    debugInfoRow("Bundle ID:", Bundle.main.bundleIdentifier ?? "Unknown")
                    debugInfoRow("Version:", Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown")
                    debugInfoRow("Build:", Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "Unknown")
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
    }
    
    private func debugInfoRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .fontWeight(.medium)
            Text(value)
                .lineLimit(1)
                .truncationMode(.middle)
        }
    }
}

// MARK: - Shortcut Recording Overlay
struct RecordingView: NSViewRepresentable {
    @Binding var isRecording: Bool
    let onRecord: (UInt32, UInt32) -> Void
    
    func makeNSView(context: Context) -> RecordingNSView {
        let v = RecordingNSView()
        v.onRecord = { keyCode, modifiers in
            onRecord(keyCode, modifiers)
            DispatchQueue.main.async { isRecording = false }
        }
        return v
    }
    
    func updateNSView(_ nsView: RecordingNSView, context: Context) {
        nsView.setRecording(isRecording)
    }
}

class RecordingNSView: NSView {
    private(set) var isRecording: Bool = false
    var onRecord: ((UInt32, UInt32) -> Void)?
    
    override var acceptsFirstResponder: Bool { true }
    
    func setRecording(_ recording: Bool) {
        isRecording = recording
        if recording {
            window?.makeFirstResponder(self)
        }
    }
    
    override func keyDown(with event: NSEvent) {
        guard isRecording else { return }
        let keyCode = UInt32(event.keyCode)
        let modifiers = convertModifiers(event.modifierFlags)
        onRecord?(keyCode, modifiers)
    }
    
    private func convertModifiers(_ flags: NSEvent.ModifierFlags) -> UInt32 {
        var mods: UInt32 = 0
        if flags.contains(.shift) { mods |= UInt32(shiftKey) }
        if flags.contains(.control) { mods |= UInt32(controlKey) }
        if flags.contains(.option) { mods |= UInt32(optionKey) }
        if flags.contains(.command) { mods |= UInt32(cmdKey) }
        return mods
    }
}

// MARK: - Helpers
private func shortcutDisplayString(keyCode: UInt32, modifiers: UInt32) -> String {
    var parts: [String] = []
    if (modifiers & UInt32(cmdKey)) != 0 { parts.append("⌘") }
    if (modifiers & UInt32(shiftKey)) != 0 { parts.append("⇧") }
    if (modifiers & UInt32(optionKey)) != 0 { parts.append("⌥") }
    if (modifiers & UInt32(controlKey)) != 0 { parts.append("⌃") }
    let key = keyCodeToString(keyCode)
    parts.append(key)
    return parts.joined()
}

private func keyCodeToString(_ keyCode: UInt32) -> String {
    switch keyCode {
    case UInt32(kVK_ANSI_A)...UInt32(kVK_ANSI_Z):
        let index = Int(keyCode - UInt32(kVK_ANSI_A))
        let scalars = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ".unicodeScalars)
        if index >= 0 && index < scalars.count {
            return String(Character(scalars[index]))
        }
        return "Key\(keyCode)"
    case UInt32(kVK_Space): return "Space"
    case UInt32(kVK_Return): return "Return"
    case UInt32(kVK_Escape): return "Esc"
    default:
        return "Key\(keyCode)"
    }
}

#Preview {
    ContentView()
}
