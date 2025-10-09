//
//  HotkeyFeedback.swift
//  tweaks
//
//  Visual and audio feedback for hotkey testing
//

import AppKit
import Combine
import SwiftUI

@MainActor
class HotkeyFeedbackManager: ObservableObject {
  static let shared = HotkeyFeedbackManager()

  @Published var lastHotkeyPressed: Date?
  @Published var hotkeyPressCount: Int = 0
  @Published var showingFeedback: Bool = false
  @Published var isLoading: Bool = false

  private var feedbackWindow: NSWindow?
  private var hideTimer: Timer?
  private var activeLoadingCount: Int = 0

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
    let timer = Timer(
      timeInterval: 2.0, target: self, selector: #selector(handleHideTimer(_:)), userInfo: nil,
      repeats: false)
    RunLoop.main.add(timer, forMode: .common)
    hideTimer = timer
  }

  func beginLoading() {
    // Ensure visual feedback is visible while loading
    activeLoadingCount += 1
    if !showingFeedback {
      showVisualFeedback()
      showingFeedback = true
    }
    hideTimer?.invalidate()
    isLoading = true
  }

  func endLoading() {
    guard activeLoadingCount > 0 else { return }
    activeLoadingCount -= 1
    if activeLoadingCount == 0 {
      isLoading = false
      // Schedule a gentle hide shortly after completion
      hideTimer?.invalidate()
      let timer = Timer(
        timeInterval: 0.9, target: self, selector: #selector(handleHideTimer(_:)), userInfo: nil,
        repeats: false)
      RunLoop.main.add(timer, forMode: .common)
      hideTimer = timer
    }
  }

  private func showVisualFeedback() {
    DispatchQueue.main.async {
      // Create or reuse feedback window
      if self.feedbackWindow == nil {
        let fixedSize = NSSize(width: 200, height: 60)
        let window = NSWindow(
          contentRect: NSRect(origin: .zero, size: fixedSize),
          styleMask: [.borderless],
          backing: .buffered,
          defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .floating
        window.isReleasedWhenClosed = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let controller = NSHostingController(rootView: HotkeyFeedbackView())
        window.contentViewController = controller

        // Lock the content size to avoid NSHostingView resizing the window during layout
        window.setContentSize(fixedSize)
        window.contentMinSize = fixedSize
        window.contentMaxSize = fixedSize

        self.feedbackWindow = window
      }

      // Position window at bottom right of screen
      if let screen = NSScreen.main, let window = self.feedbackWindow {
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        let x = screenFrame.maxX - windowFrame.width - 20
        let y = screenFrame.minY + 20
        window.setFrameOrigin(NSPoint(x: x, y: y))
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

      NSAnimationContext.runAnimationGroup(
        { context in
          context.duration = 0.2
          window.animator().alphaValue = 0
        },
        completionHandler: {
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
  @ObservedObject private var feedback = HotkeyFeedbackManager.shared
  var body: some View {
    HStack(spacing: 8) {
      if feedback.isLoading {
        ProgressView()
          .progressViewStyle(.circular)
          .tint(.white)
      } else {
        Image(systemName: "keyboard")
          .font(.title2)
          .foregroundColor(.white)
      }

      VStack(alignment: .leading, spacing: 2) {
        Text("Hotkey Triggered!")
          .font(.system(.body, weight: .medium))
          .foregroundColor(.white)

        Text(feedback.isLoading ? "Tweaking via Osaurus..." : "Ready")
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

// (Removed unused HotkeyTestView)
