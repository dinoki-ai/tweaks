//
//  QuickTweakMenu.swift
//  tweaks
//
//  Small transient menu shown near the mouse cursor on hotkey press
//

import AppKit
import SwiftUI

// MARK: - Model

struct TweakAction: Identifiable {
  let id = UUID()
  let number: Int
  let title: String
  let subtitle: String
  let systemPrompt: String
}

// MARK: - Presenter

@MainActor
final class QuickTweakMenuPresenter: NSObject {
  static let shared = QuickTweakMenuPresenter()

  private var hudWindow: NSWindow?
  private var actions: [TweakAction] = QuickTweakMenuPresenter.defaultActions

  // CGEvent tap to intercept digit keys while HUD is visible
  private var eventTap: CFMachPort?
  private var eventTapRunLoopSource: CFRunLoopSource?
  // Track previous front app for fallback key capture when tap is unavailable
  private var previousFrontApp: NSRunningApplication?
  private var activatedForKeyCapture: Bool = false

  // Note: legacy popover/caret code removed in favor of centered HUD

  func showCenteredHUD() {
    // Close any existing instance first
    close()

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 10, height: 10),
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.isOpaque = false
    window.backgroundColor = .clear
    window.hasShadow = true
    window.ignoresMouseEvents = false
    window.level = .floating
    window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    window.isReleasedWhenClosed = false

    // Refresh actions from settings each time HUD is shown
    actions = Self.actionsFromSettings()

    let view = CenteredTweakHUDView(
      actions: actions,
      onSelect: { [weak self] action in
        self?.performAction(forNumber: action.number)
      },
      onDismiss: { [weak self] in
        self?.close()
      }
    )
    let controller = NSHostingController(rootView: view)
    window.contentViewController = controller
    controller.view.layoutSubtreeIfNeeded()
    let fit = controller.view.fittingSize
    let screenFrame = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1440, height: 900)
    let targetSize = NSSize(
      width: min(max(fit.width, 320), screenFrame.width - 80),
      height: min(max(fit.height, 80), 220)
    )
    // Position slightly above vertical center (~25% of the way toward the top)
    // y = centerY + 0.25 * (topMargin - centerY)
    let centerY = screenFrame.midY - targetSize.height / 2
    let topMargin = screenFrame.maxY - targetSize.height - 80  // keep safe margin from very top
    let liftedY = centerY + 0.25 * (topMargin - centerY)
    let origin = NSPoint(
      x: screenFrame.midX - targetSize.width / 2,
      y: liftedY
    )
    window.setFrame(NSRect(origin: origin, size: targetSize), display: true)

    window.orderFrontRegardless()
    hudWindow = window

    // Attempt global digit interception; fall back to local key focus if unavailable
    previousFrontApp = NSWorkspace.shared.frontmostApplication
    let tapInstalled = installDigitInterceptionTap()
    if !tapInstalled {
      if #available(macOS 14.0, *) {
        NSApp.activate()
      } else {
        NSApp.activate(ignoringOtherApps: true)
      }
      window.makeKeyAndOrderFront(nil)
      activatedForKeyCapture = true
    } else {
      activatedForKeyCapture = false
    }
  }

  func close() {
    if let window = hudWindow {
      window.orderOut(nil)
      hudWindow = nil
    }

    uninstallDigitInterceptionTap()

    // Restore previous front app focus if we had to activate for key capture
    if activatedForKeyCapture {
      previousFrontApp?.activate(options: [])
    }
    previousFrontApp = nil
    activatedForKeyCapture = false
  }

  // Default actions used by the menu
  private static var defaultActions: [TweakAction] {
    [
      TweakAction(
        number: 1,
        title: "Rewrite for clarity",
        subtitle: "Make it clear, concise, and natural",
        systemPrompt:
          "You are an assistant that rewrites text for clarity. Keep the author’s intent. Use plain language and reduce redundancy."
      ),
      TweakAction(
        number: 2,
        title: "Summarize (bullets)",
        subtitle: "3–5 bullets, key points only",
        systemPrompt:
          "Summarize the text in 3–5 concise bullet points. Capture only the key ideas and facts."
      ),
      TweakAction(
        number: 3,
        title: "Shorten (~30%)",
        subtitle: "Keep tone; cut fluff",
        systemPrompt:
          "Shorten the text by ~30% while preserving meaning, voice, and critical details."
      ),
      TweakAction(
        number: 4,
        title: "Formalize",
        subtitle: "Polite, professional tone",
        systemPrompt:
          "Rewrite the text in a polite, professional tone suitable for business email. Avoid sounding stiff or robotic."
      ),
    ]
  }

  // Build actions from SettingsManager quick slots, fall back to defaults if missing
  private static func actionsFromSettings() -> [TweakAction] {
    let slots = SettingsManager.shared.quickSlots
    let enabled = slots.filter { $0.isEnabled }
    if enabled.isEmpty {
      return defaultActions
    }
    return enabled.sorted { $0.number < $1.number }.map {
      TweakAction(
        number: $0.number,
        title: $0.title,
        subtitle: $0.subtitle,
        systemPrompt: $0.systemPrompt
      )
    }
  }
}

// MARK: - Key Capture

final class KeyCatcherView: NSView {
  var onKeyDown: ((UInt16, String?) -> Void)?
  override var acceptsFirstResponder: Bool { true }
  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.makeFirstResponder(self)
  }
  override func keyDown(with event: NSEvent) {
    onKeyDown?(event.keyCode, event.characters)
  }
}

struct KeyCatcher: NSViewRepresentable {
  var onKeyDown: (UInt16, String?) -> Void
  func makeNSView(context: Context) -> KeyCatcherView {
    let v = KeyCatcherView()
    v.onKeyDown = onKeyDown
    DispatchQueue.main.async { v.window?.makeFirstResponder(v) }
    return v
  }
  func updateNSView(_ nsView: KeyCatcherView, context: Context) {}
}

// MARK: - Centered HUD View

struct CenteredTweakHUDView: View {
  let actions: [TweakAction]
  var onSelect: (TweakAction) -> Void
  var onDismiss: () -> Void

  @State private var highlighted: Int? = nil
  @State private var autoDismissWorkItem: DispatchWorkItem? = nil

  var body: some View {
    HStack(spacing: 12) {
      ForEach(actions) { action in
        Button(action: { onSelect(action) }) {
          HStack(spacing: 10) {
            Text(action.title)
              .font(.system(size: 14, weight: .semibold))
              .foregroundColor(.white)
            Text("\(action.number)")
              .font(.system(size: 13, weight: .semibold, design: .monospaced))
              .foregroundColor(.white.opacity(0.7))
              .padding(.horizontal, 8)
              .padding(.vertical, 4)
              .background(
                RoundedRectangle(cornerRadius: 6)
                  .fill(Color.white.opacity(0.08))
              )
          }
          .padding(.horizontal, 14)
          .padding(.vertical, 12)
          .background(
            RoundedRectangle(cornerRadius: 10)
              .fill(
                highlighted == action.number ? Color.white.opacity(0.16) : Color.white.opacity(0.08)
              )
          )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
          highlighted = hovering ? action.number : nil
        }
      }
    }
    .padding(.horizontal, 14)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 14)
        .fill(Color.black.opacity(0.28))
        .overlay(
          RoundedRectangle(cornerRadius: 14)
            .stroke(Color.white.opacity(0.12), lineWidth: 0.75)
        )
    )
    .overlay(
      KeyCatcher { _, chars in
        guard let c = chars?.first else { return }
        if c >= "1" && c <= "4" {
          let selected = Int(String(c))!
          highlighted = selected
          if let action = actions.first(where: { $0.number == selected }) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
              onSelect(action)
            }
          }
        } else if c == "\u{1B}" {
          onDismiss()
        }
      }
      .allowsHitTesting(false)
    )
    .onAppear(perform: scheduleAutoDismiss)
    .onDisappear { autoDismissWorkItem?.cancel() }
  }

  private func scheduleAutoDismiss() {
    autoDismissWorkItem?.cancel()
    let work = DispatchWorkItem { onDismiss() }
    autoDismissWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5, execute: work)
  }
}

// MARK: - Global Digit Interception

extension QuickTweakMenuPresenter {
  private func installDigitInterceptionTap() -> Bool {
    if eventTap != nil { return true }

    let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
    let callback: CGEventTapCallBack = { _, type, event, userInfo in
      guard type == .keyDown, let userInfo = userInfo else {
        return Unmanaged.passUnretained(event)
      }
      let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

      // Map keycodes to digits 1..4 on ANSI layout and numeric keypad
      let digit: Int?
      switch keyCode {
      case 18: digit = 1  // kVK_ANSI_1
      case 19: digit = 2  // kVK_ANSI_2
      case 20: digit = 3  // kVK_ANSI_3
      case 21: digit = 4  // kVK_ANSI_4
      case 83: digit = 1  // kVK_ANSI_Keypad1
      case 84: digit = 2  // kVK_ANSI_Keypad2
      case 85: digit = 3  // kVK_ANSI_Keypad3
      case 86: digit = 4  // kVK_ANSI_Keypad4
      default: digit = nil
      }

      guard let number = digit else {
        return Unmanaged.passUnretained(event)
      }

      // Forward selection to presenter on main thread and swallow the event
      let presenter = Unmanaged<QuickTweakMenuPresenter>.fromOpaque(userInfo).takeUnretainedValue()
      DispatchQueue.main.async {
        presenter.performAction(forNumber: number)
      }
      return nil  // consume; prevent typing "1" into the foreground app
    }

    if let tap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: mask,
      callback: callback,
      userInfo: Unmanaged.passUnretained(self).toOpaque()
    ) {
      eventTap = tap
      let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
      eventTapRunLoopSource = source
      CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
      CGEvent.tapEnable(tap: tap, enable: true)
      return true
    } else {
      #if DEBUG
        print("[QuickTweakMenuPresenter] Failed to create CGEvent tap for digit interception")
      #endif
      return false
    }
  }

  private func uninstallDigitInterceptionTap() {
    if let source = eventTapRunLoopSource {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
      eventTapRunLoopSource = nil
    }
    if let tap = eventTap {
      CGEvent.tapEnable(tap: tap, enable: false)
      eventTap = nil
    }
  }

  private func performAction(forNumber number: Int) {
    guard let action = actions.first(where: { $0.number == number }) else { return }
    TweakService.shared.pasteTweakedText(usingSystemPrompt: action.systemPrompt)
    close()
  }
}
