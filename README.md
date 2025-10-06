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

## Development

For developers, we've included tools to make debugging easier:

- **Debug Tab**: One-click accessibility setup for each build
- **Visual Feedback**: Toast notifications and status indicators
- **Development Script**: Run `./dev_setup.sh` for guided setup

See [DEBUG_SETUP.md](DEBUG_SETUP.md) for detailed development instructions.

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

- Default: `Control+T`.
- Change it in the Settings tab. While recording, the current hotkey is temporarily suspended to avoid accidental triggers.

### Privacy

- All keyboard events require Accessibility permission. Your text is sent only to the endpoint you configure (local by default).

## Architecture

```
tweaks/
├── tweaksApp.swift           # App entry point
├── AppDelegate.swift         # Menu bar and popover wiring
├── ContentView.swift         # Main UI (Overview, AI Model, Settings)
│
├── HotkeyManager.swift       # Centralized global hotkey registration/handler
├── TweakService.swift        # Clipboard → AI → paste flow (streaming + restore)
├── ShortcutRecorder.swift    # NSView wrapper to capture keyboard shortcuts
├── ShortcutUtils.swift       # Display/convert key codes and modifiers
│
├── PermissionManager.swift   # Accessibility permission state and prompts
├── HotkeyFeedback.swift      # Visual/audio feedback and test view
│
├── Osaurus.swift             # Minimal OpenAI-compatible client and defaults
├── FuturisticUI.swift        # Theme + reusable UI components
└── DebugHelpers.swift        # Debug-only utilities
```

### AI internals

- `Osaurus.Defaults` sets default `model`, `systemPrompt`, and `temperature`.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Troubleshooting

- Nothing happens on hotkey
  - Ensure Accessibility is granted (open the app → follow the prompt or see the Debug tab)
  - Some apps enable Secure Input and block simulated keystrokes; try another app
- AI does not change the text
  - Verify your server is reachable at `OSAURUS_BASE_URL`
  - Check logs in the Xcode console (Debug build prints helpful messages)
  - Confirm your endpoint is OpenAI-compatible and returns `choices[0].message.content`
- Privacy
  - Your clipboard text is sent to the server you configure. For maximum privacy, use a local server.
