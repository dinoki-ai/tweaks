# Tweaks 🧠📋

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Swift](https://img.shields.io/badge/Swift-5.9-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS%2014.0%2B-lightgrey.svg)](https://www.apple.com/macos/)
[![Xcode](https://img.shields.io/badge/Xcode-16.0%2B-blue.svg)](https://developer.apple.com/xcode/)
[![Apple Silicon](https://img.shields.io/badge/Apple%20Silicon-Required-red.svg)](https://support.apple.com/en-us/HT211814)

A simple macOS menu bar app that improves your clipboard text with AI and generates a new paste.

## Features

- **AI-Powered Tweaks**: Improves clipboard text via an OpenAI-compatible API ("Osaurus")
- **Global Hotkey**: Press `Control+T` (customizable) to paste improved text
- **Menu Bar App**: Lives quietly in your menu bar
- **Visual Feedback**: See when hotkeys are triggered
- **Easy Setup**: Clear onboarding for accessibility permissions

## Prerequisites

### Osaurus - Local LLM Server

Tweaks requires [Osaurus](https://github.com/dinoki-ai/osaurus), a native Apple Silicon local LLM server, to provide AI-powered text improvements. Osaurus is built on Apple's MLX for maximum performance on M-series chips.

#### Installation

Install Osaurus using Homebrew:

```bash
brew install osaurus
```

#### Setup

1. **Launch Osaurus**: After installation, launch Osaurus from your Applications folder or by running:

   ```bash
   osaurus
   ```

2. **Download a Model**:

   - Click on the Osaurus menu bar icon
   - Go to "Model Gallery" or "Downloads"
   - Choose a model. Recommended options:
     - **For beginners**: `Llama 3.2 3B Instruct 4bit` (fast, good quality)
     - **For better quality**: `Qwen 2.5 7B Instruct 4bit` (slower, more capable)
     - **For speed**: `Phi 3.5 Mini Instruct 4bit` (very fast, decent quality)
   - Click "Download" and wait for it to complete

3. **Verify it's Running**:
   - Osaurus runs on `http://localhost:1337` by default
   - You should see the Osaurus icon in your menu bar when it's active
4. **Test the API** (optional):
   ```bash
   curl http://127.0.0.1:1337/v1/chat/completions \
     -H "Content-Type: application/json" \
     -d '{
       "model": "llama-3.2-3b-instruct-4bit",
       "messages": [{"role":"user","content":"Hello"}]
     }'
   ```

> **Note**: Osaurus requires Apple Silicon (M1/M2/M3 chips). Intel Macs are not supported.

## Installation

1. Clone the repository
2. Open `tweaks.xcodeproj` in Xcode
3. Build and run (Cmd+R)

## Development & Debugging

### Quick Start for Debug Builds

Every time you build in debug mode, macOS treats it as a new app that needs accessibility permissions. We've included tools to make this process easier.

#### Method 1: Using the Debug Tab (Recommended)

1. **Run the app** from Xcode
2. **Click the menu bar icon** (gear icon)
3. **Go to Debug tab**
4. **Click "Setup Accessibility"** button
   - This automatically opens System Settings and copies the app path
5. **In System Settings:**
   - Click the "+" button
   - Press Cmd+V to paste the path
   - Select the app and click "Open"
   - Toggle the switch ON

#### Method 2: Using the Debug Script

1. **Run the app** from Xcode
2. **Click the menu bar icon** (gear icon)
3. **Go to Debug tab**
4. **Click "Debug Script"**
   - This creates and runs a Terminal script that guides you through the process

#### Method 3: Manual Process

1. Find your debug build location:
   ```
   ~/Library/Developer/Xcode/DerivedData/tweaks-*/Build/Products/Debug/tweaks.app
   ```
2. Open System Settings > Privacy & Security > Accessibility
3. Remove any old "tweaks" entries with "-" button
4. Click "+" and navigate to the path above
5. Toggle ON

### Visual Feedback System

The app includes comprehensive feedback for debugging:

1. **Permission Status Indicator**

   - Green checkmark = Ready to use
   - Orange warning = Permission needed
   - Red X = Permission denied

2. **Hotkey Test Feature**

   - Main tab shows "Test Hotkey Now" button when permissions are granted
   - Press count and last press time are displayed
   - Visual indicator pulses when hotkey is triggered
   - Toast notification appears in bottom-right corner

3. **Debug Build Detection**
   - Automatically detects when running from Xcode
   - Shows special debug helper UI
   - Provides one-click setup process

### Development Tips

1. **Keep the Debug tab open** during development for quick access
2. **Use the feedback system** to verify changes immediately
3. **The app remembers** your custom hotkey between launches
4. **Visual feedback** appears even without clipboard content

## Requirements

- macOS 14.0 or later (Apple Silicon M1/M2/M3 required)
- Xcode 16.0 or later
- [Osaurus](https://github.com/dinoki-ai/osaurus) - Local LLM server (see Prerequisites above)
- Accessibility permission (for hotkey functionality)

## Usage

1. **First Run**: Grant accessibility permission when prompted
2. **Use Hotkey**: Press `Control+T` to paste AI‑improved clipboard text
3. **Customize**: Click the menu bar icon → Settings to change hotkey

Behavior details:

- Tweaks reads your clipboard, sends it to your configured AI endpoint, and temporarily replaces your clipboard with the improved text.
- It then presses `Cmd+V` for you to paste in the foreground app and restores your original clipboard shortly after.
- If the AI call fails, Tweaks falls back to pasting your original clipboard unchanged.

### Hotkey

- **Default: `Control+T`** - Improves clipboard text with AI before pasting
- Change it in the Settings tab by clicking "Change" and pressing your desired combination
- While recording, the current hotkey is temporarily suspended to avoid accidental triggers

### Privacy

- All keyboard events require Accessibility permission
- Your text is sent only to the endpoint you configure (local by default)

## Architecture

```
tweaks/
├── App/                      # App entry point and app lifecycle
│   ├── tweaksApp.swift
│   └── AppDelegate.swift
├── UI/                       # Main UI and reusable components
│   ├── ContentView.swift
│   ├── HotkeyFeedback.swift
│   ├── PromptEditorView.swift
│   └── FuturisticUI.swift
├── Hotkey/                   # Global hotkey capture and helpers
│   ├── HotkeyManager.swift
│   ├── ShortcutRecorder.swift
│   └── ShortcutUtils.swift
├── Permissions/              # Accessibility permission state and prompts
│   └── PermissionManager.swift
├── Services/                 # Clipboard → AI → paste flow
│   └── TweakService.swift
├── AI/                       # OpenAI-compatible client and defaults
│   └── Osaurus.swift
├── Settings/                 # User defaults and app settings
│   └── SettingsManager.swift
├── Debug/                    # Debug-only utilities
│   └── DebugHelpers.swift
├── Assets.xcassets
├── Info.plist
└── tweaks.entitlements
```

### AI internals

- `Osaurus.Defaults` sets default `model`, `systemPrompt`, and `temperature`.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Troubleshooting

### Nothing happens on hotkey

- Ensure Accessibility is granted (open the app → follow the prompt or see the Debug tab)
- Check the visual indicator in the top-right of the popover
- Use "Test Hotkey Now" button to verify functionality
- Ensure no other apps are using the same hotkey combination
- Some apps enable Secure Input and block simulated keystrokes; try another app

### "Permission Required" Won't Go Away

- Ensure you're granting permission to the exact build path
- Try quitting and reopening the app after granting permission
- Use the "Quit & Reopen" button in Debug tab

### Debug Build Path Changed

This happens when Xcode creates a new DerivedData folder:

1. Use the Debug tab's "Setup Accessibility" button
2. It automatically handles the new path

### AI does not change the text

- Verify your server is reachable at `OSAURUS_BASE_URL`
- Check logs in the Xcode console (Debug build prints helpful messages)
- Confirm your endpoint is OpenAI-compatible and returns `choices[0].message.content`

### Privacy

- Your clipboard text is sent to the server you configure. For maximum privacy, use a local server.
