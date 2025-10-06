//
//  HotkeyFeedback.swift
//  tweaks
//
//  Visual and audio feedback for hotkey testing
//

import SwiftUI
import AppKit
import Combine

@MainActor
class HotkeyFeedbackManager: ObservableObject {
    static let shared = HotkeyFeedbackManager()
    
    @Published var lastHotkeyPressed: Date?
    @Published var hotkeyPressCount: Int = 0
    @Published var showingFeedback: Bool = false
    
    private var feedbackWindow: NSWindow?
    private var hideTimer: Timer?
    
    func hotkeyTriggered() {
        lastHotkeyPressed = Date()
        hotkeyPressCount += 1
        
        // Audio feedback
        #if DEBUG
        NSSound.beep()
        #endif
        
        // Visual feedback
        showVisualFeedback()
        
        // Update state
        DispatchQueue.main.async {
            self.showingFeedback = true
        }
        
        // Hide after delay
        hideTimer?.invalidate()
        let timer = Timer(timeInterval: 2.0, target: self, selector: #selector(handleHideTimer(_:)), userInfo: nil, repeats: false)
        RunLoop.main.add(timer, forMode: .common)
        hideTimer = timer
    }
    
    private func showVisualFeedback() {
        DispatchQueue.main.async {
            // Create or reuse feedback window
            if self.feedbackWindow == nil {
                let window = NSWindow(
                    contentRect: NSRect(x: 0, y: 0, width: 200, height: 60),
                    styleMask: [.borderless],
                    backing: .buffered,
                    defer: false
                )
                window.isOpaque = false
                window.backgroundColor = .clear
                window.level = .floating
                window.isReleasedWhenClosed = false
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
                
                let contentView = NSHostingView(rootView: HotkeyFeedbackView())
                window.contentView = contentView
                
                self.feedbackWindow = window
            }
            
            // Position window at bottom right of screen
            if let screen = NSScreen.main {
                let screenFrame = screen.visibleFrame
                let windowFrame = self.feedbackWindow!.frame
                let x = screenFrame.maxX - windowFrame.width - 20
                let y = screenFrame.minY + 20
                self.feedbackWindow!.setFrameOrigin(NSPoint(x: x, y: y))
            }
            
            // Show with animation
            self.feedbackWindow!.alphaValue = 0
            self.feedbackWindow!.orderFront(nil)
            NSAnimationContext.runAnimationGroup { context in
                context.duration = 0.2
                self.feedbackWindow!.animator().alphaValue = 1
            }
        }
    }
    
    private func hideVisualFeedback() {
        DispatchQueue.main.async {
            guard let window = self.feedbackWindow else { return }
            
            NSAnimationContext.runAnimationGroup({ context in
                context.duration = 0.2
                window.animator().alphaValue = 0
            }, completionHandler: {
                window.orderOut(nil)
            })
        }
    }
}

extension HotkeyFeedbackManager {
    @objc private func handleHideTimer(_ timer: Timer) {
        showingFeedback = false
        hideVisualFeedback()
    }
}

struct HotkeyFeedbackView: View {
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "keyboard")
                .font(.title2)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 2) {
                Text("Hotkey Triggered!")
                    .font(.system(.body, weight: .medium))
                    .foregroundColor(.white)
                
                Text("Pasting with emoji...")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.green)
                .shadow(radius: 10)
        )
    }
}

// Test button for the main UI
struct HotkeyTestView: View {
    @ObservedObject var feedback = HotkeyFeedbackManager.shared
    @State private var pulseAnimation = false
    
    private var timeSinceLastPress: String {
        guard let lastPressed = feedback.lastHotkeyPressed else {
            return "Never"
        }
        
        let interval = Date().timeIntervalSince(lastPressed)
        if interval < 60 {
            return "\(Int(interval))s ago"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m ago"
        } else {
            return ">1h ago"
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "keyboard")
                    .foregroundColor(.secondary)
                Text("Hotkey Testing")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Press Count: \(feedback.hotkeyPressCount)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("Last Press: \(timeSinceLastPress)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Visual indicator
                Circle()
                    .fill(feedback.showingFeedback ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulseAnimation ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.3), value: pulseAnimation)
                    .onChange(of: feedback.showingFeedback) { old, newValue in
                        if newValue {
                            pulseAnimation = true
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                pulseAnimation = false
                            }
                        }
                    }
            }
            
            Button(action: {
                (NSApp.delegate as? AppDelegate)?.pasteTextWithEmoji()
                feedback.hotkeyTriggered()
            }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Test Hotkey Now")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(8)
    }
}
