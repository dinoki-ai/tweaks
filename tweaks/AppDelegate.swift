//
//  AppDelegate.swift
//  tweaks
//
//  Created by Terence on 10/5/25.
//

import SwiftUI
import AppKit
import Carbon

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var popover = NSPopover()
    var hotKeyRef: EventHotKeyRef?
    var hotKeyEventHandler: EventHandlerRef?
    let hotkeyKeyCodeDefaultsKey = "HotkeyKeyCode"
    let hotkeyModifiersDefaultsKey = "HotkeyModifiers"
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set activation policy to accessory (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Create the status bar item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "gear", accessibilityDescription: "Tweaks")
            button.action = #selector(togglePopover)
        }
        
        // Configure the popover
        popover.contentSize = NSSize(width: 300, height: 500)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: ContentView())
        
        // Install hotkey handler once and register from saved settings
        installHotkeyHandlerIfNeeded()
        let defaults = UserDefaults.standard
        let defaultKeyCode = UInt32(kVK_ANSI_T)
        let defaultModifiers = UInt32(controlKey)
        let keyCode = defaults.object(forKey: hotkeyKeyCodeDefaultsKey) != nil ? UInt32(defaults.integer(forKey: hotkeyKeyCodeDefaultsKey)) : defaultKeyCode
        let modifiers = defaults.object(forKey: hotkeyModifiersDefaultsKey) != nil ? UInt32(defaults.integer(forKey: hotkeyModifiersDefaultsKey)) : defaultModifiers
        registerGlobalHotkey(keyCode: keyCode, modifiers: modifiers)
    }
    
    @objc func togglePopover() {
        guard let button = statusItem?.button else { return }
        
        if popover.isShown {
            popover.performClose(nil)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
    
    func installHotkeyHandlerIfNeeded() {
        guard hotKeyEventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { (callRef, eventRef, userData) -> OSStatus in
            guard let eventRef = eventRef else { return noErr }
            var hotKeyID = EventHotKeyID()
            let status = GetEventParameter(eventRef,
                                           EventParamName(kEventParamDirectObject),
                                           EventParamType(typeEventHotKeyID),
                                           nil,
                                           MemoryLayout<EventHotKeyID>.size,
                                           nil,
                                           &hotKeyID)
            if status == noErr && hotKeyID.id == 1 {
                // Debug: hotkey recognized
                if DebugHelpers.isDebugBuild {
                    let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
                    print("[Tweaks] Hotkey pressed. Frontmost app=\(activeApp)")
                }
                // Resolve delegate from userData if available; fallback to NSApp.delegate
                let appDelegate: AppDelegate? = {
                    if let userData = userData {
                        return Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()
                    }
                    return NSApp.delegate as? AppDelegate
                }()
                
                // Invoke paste on main thread
                if let appDelegate {
                    if DebugHelpers.isDebugBuild { print("[Tweaks] Queuing pasteTextWithEmoji on main") }
                    DispatchQueue.main.async {
                        if DebugHelpers.isDebugBuild { print("[Tweaks] Dispatching pasteTextWithEmoji on main thread") }
                        appDelegate.pasteTextWithEmoji()
                    }
                } else {
                    if DebugHelpers.isDebugBuild { print("[Tweaks] Could not resolve AppDelegate for paste invocation") }
                }
                // Trigger feedback
                DispatchQueue.main.async {
                    HotkeyFeedbackManager.shared.hotkeyTriggered()
                }
            }
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &hotKeyEventHandler)
    }

    func registerGlobalHotkey(keyCode: UInt32, modifiers: UInt32) {
        // Unregister previous hotkey if any
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }
        // Avoid deprecated UTGetOSTypeFromString; use literal four-char code for 'TWKS'
        let signature: OSType = 0x54574B53
        let hotKeyID = EventHotKeyID(signature: signature, id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID, GetApplicationEventTarget(), 0, &hotKeyRef)
        if status != noErr {
            print("RegisterEventHotKey failed: \(status)")
        }
    }

    func updateGlobalHotkey(keyCode: UInt32, modifiers: UInt32) {
        let defaults = UserDefaults.standard
        defaults.set(Int(keyCode), forKey: hotkeyKeyCodeDefaultsKey)
        defaults.set(Int(modifiers), forKey: hotkeyModifiersDefaultsKey)
        registerGlobalHotkey(keyCode: keyCode, modifiers: modifiers)
    }
    
    func pasteTextWithEmoji() {
        if DebugHelpers.isDebugBuild {
            let trusted = AXIsProcessTrusted()
            #if canImport(Carbon)
            let secureInput = IsSecureEventInputEnabled()
            #else
            let secureInput = false
            #endif
            let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
            print("[Tweaks] Enter pasteTextWithEmoji trusted=\(trusted) secureInput=\(secureInput) app=\(activeApp)")
        }
        // Ensure we have accessibility permission before attempting to post events
        guard AXIsProcessTrusted() else {
            if DebugHelpers.isDebugBuild {
                print("[Tweaks] Accessibility not trusted. Aborting paste.")
            }
            return
        }
        
        let pasteboard = NSPasteboard.general
        
        // Check if clipboard contains text
        if let text = pasteboard.string(forType: .string) {
            if DebugHelpers.isDebugBuild {
                print("[Tweaks] Clipboard detected. Length=\(text.count)")
            }
            // Save current clipboard content
            let originalContent = text
            
            // Add emoji to the text
            let textWithEmoji = text + " 😊"
            
            // Temporarily set clipboard to text with emoji
            pasteboard.clearContents()
            let setOk = pasteboard.setString(textWithEmoji, forType: .string)
            if DebugHelpers.isDebugBuild {
                print("[Tweaks] Temporary pasteboard set ok=\(setOk). Will paste via Cmd+V.")
            }
            
            // Give the system a brief moment to observe the new pasteboard contents
            let prePasteDelay: TimeInterval = 0.02
            let restoreDelay: TimeInterval = 0.50
            
            DispatchQueue.main.asyncAfter(deadline: .now() + prePasteDelay) {
                func postCmdV(tap: CGEventTapLocation, label: String) {
                    let source = CGEventSource(stateID: .combinedSessionState)
                    // cmd down
                    let cmdDown = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: true)
                    cmdDown?.flags = .maskCommand
                    // v down
                    let vDown = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: true)
                    vDown?.flags = .maskCommand
                    // v up
                    let vUp = CGEvent(keyboardEventSource: source, virtualKey: 0x09, keyDown: false)
                    vUp?.flags = .maskCommand
                    // cmd up
                    let cmdUp = CGEvent(keyboardEventSource: source, virtualKey: 0x37, keyDown: false)
                    cmdUp?.flags = .maskCommand
                    cmdDown?.post(tap: tap)
                    // small inter-event spacing
                    usleep(1500)
                    vDown?.post(tap: tap)
                    usleep(1500)
                    vUp?.post(tap: tap)
                    usleep(1500)
                    cmdUp?.post(tap: tap)
                    if DebugHelpers.isDebugBuild {
                        let activeApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "unknown"
                        print("[Tweaks] Posted Cmd+V sequence via \(label) for app=\(activeApp)")
                    }
                }
                // Post only once via session tap (avoid duplicate pastes)
                postCmdV(tap: .cgSessionEventTap, label: "session tap")
            }
            
            // Restore original clipboard content after the paste has likely completed
            DispatchQueue.main.asyncAfter(deadline: .now() + prePasteDelay + restoreDelay) {
                pasteboard.clearContents()
                pasteboard.setString(originalContent, forType: .string)
                if DebugHelpers.isDebugBuild {
                    print("[Tweaks] Original clipboard restored. Length=\(originalContent.count)")
                }
            }
            
            // No AppleScript fallback by default to avoid accidental duplicates
        } else {
            if DebugHelpers.isDebugBuild {
                print("[Tweaks] Clipboard empty or not string. No action.")
            }
        }
    }

    private func tryAppleScriptPasteFallback() {
        guard DebugHelpers.isDebugBuild else { return }
        let frontApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? ""
        let scriptSource = """
        tell application "System Events"
            try
                keystroke "v" using {command down}
            on error errMsg number errNum
                return "ERROR: " & errNum & " - " & errMsg
            end try
        end tell
        """
        if let script = NSAppleScript(source: scriptSource) {
            var errorInfo: NSDictionary?
            let result = script.executeAndReturnError(&errorInfo)
            if let errorInfo {
                print("[Tweaks] AppleScript paste fallback error for app=\(frontApp): \(errorInfo)")
            } else {
                print("[Tweaks] AppleScript paste fallback attempted for app=\(frontApp). Result=\(result.stringValue ?? "ok")")
            }
        } else {
            print("[Tweaks] AppleScript could not be created for fallback paste.")
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        // Unregister hotkey and remove handler on terminate
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
        }
        if let hotKeyEventHandler {
            RemoveEventHandler(hotKeyEventHandler)
        }
    }
}
