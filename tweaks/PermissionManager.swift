//
//  PermissionManager.swift
//  tweaks
//
//  Manages accessibility permissions with clear state tracking
//

import SwiftUI
import AppKit
import Combine

enum AccessibilityStatus: Equatable {
    case unknown
    case notRequested
    case denied
    case granted
}

extension AccessibilityStatus {
    var icon: String {
        switch self {
        case .unknown: return "questionmark.circle"
        case .notRequested: return "exclamationmark.circle"
        case .denied: return "xmark.circle"
        case .granted: return "checkmark.circle.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .unknown: return .gray
        case .notRequested: return .orange
        case .denied: return .red
        case .granted: return .green
        }
    }
    
    var message: String {
        switch self {
        case .unknown: return "Checking permissions..."
        case .notRequested: return "Accessibility permission required"
        case .denied: return "Accessibility permission denied"
        case .granted: return "Accessibility enabled"
        }
    }
}

@MainActor class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var accessibilityStatus: AccessibilityStatus = .unknown
    @Published var lastChecked: Date = Date()
    
    private var checkTimer: Timer?
    
    
    
    init() {
        checkStatus()
        startMonitoring()
    }
    
    func checkStatus() {
        let trusted = AXIsProcessTrusted()
        
        if trusted {
            accessibilityStatus = .granted
        } else {
            // Check if we've ever requested before
            let hasRequested = UserDefaults.standard.bool(forKey: "HasRequestedAccessibility")
            accessibilityStatus = hasRequested ? .denied : .notRequested
        }
        
        lastChecked = Date()
    }
    
    func requestPermission() {
        // Mark that we've requested
        UserDefaults.standard.set(true, forKey: "HasRequestedAccessibility")
        
        // Request permission
        let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        AXIsProcessTrustedWithOptions(options)
        
        // Start checking more frequently
        startIntensiveMonitoring()
    }
    
    func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        
        // Start checking more frequently
        startIntensiveMonitoring()
    }
    
    private func startMonitoring() {
        checkTimer?.invalidate()
        let timer = Timer(timeInterval: 5.0, target: self, selector: #selector(handleNormalTimer(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        checkTimer = timer
    }
    
    private func startIntensiveMonitoring() {
        checkTimer?.invalidate()
        let timer = Timer(timeInterval: 0.5, target: self, selector: #selector(handleIntensiveTimer(_:)), userInfo: nil, repeats: true)
        RunLoop.main.add(timer, forMode: .common)
        checkTimer = timer
    }
}

extension PermissionManager {
    @objc private func handleNormalTimer(_ timer: Timer) {
        checkStatus()
    }
    
    @objc private func handleIntensiveTimer(_ timer: Timer) {
        checkStatus()
        
        // If granted, go back to normal monitoring
        if accessibilityStatus == .granted {
            startMonitoring()
        }
    }
}

// Simplified permission view
struct PermissionStatusView: View {
    @ObservedObject var manager = PermissionManager.shared
    @State private var showingHelp = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: manager.accessibilityStatus.icon)
                    .foregroundColor(manager.accessibilityStatus.color)
                    .imageScale(.large)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(manager.accessibilityStatus.message)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    if manager.accessibilityStatus != .granted {
                        Text("Required for hotkey functionality")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if manager.accessibilityStatus != .granted {
                    Button(action: { showingHelp.toggle() }) {
                        Image(systemName: "questionmark.circle")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            
            if manager.accessibilityStatus == .notRequested {
                Button(action: { manager.requestPermission() }) {
                    HStack {
                        Image(systemName: "key.fill")
                        Text("Enable Accessibility")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else if manager.accessibilityStatus == .denied {
                HStack(spacing: 8) {
                    Button(action: { manager.openSystemPreferences() }) {
                        HStack {
                            Image(systemName: "gear")
                            Text("System Settings")
                        }
                    }
                    .buttonStyle(.bordered)
                    
                    Button(action: { manager.requestPermission() }) {
                        Text("Try Again")
                    }
                    .buttonStyle(.bordered)
                }
            }
            
            if showingHelp {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Why is this needed?")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Accessibility permission allows the app to simulate keyboard shortcuts for pasting text.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.2), value: manager.accessibilityStatus)
        .animation(.easeInOut(duration: 0.2), value: showingHelp)
    }
}

