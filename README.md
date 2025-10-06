# Tweaks 🎯

A simple macOS menu bar app that improves your clipboard text with AI and pastes it.

## Features

- **AI-Powered Tweaks**: Improves clipboard text via an OpenAI-compatible API ("Osaurus")
- **Global Hotkey**: Press `Control+T` (customizable) to paste improved text
- **Menu Bar App**: Lives quietly in your menu bar
- **Visual Feedback**: See when hotkeys are triggered
- **Easy Setup**: Clear onboarding for accessibility permissions

## Installation

1. Clone the repository
2. Open `tweaks.xcodeproj` in Xcode
3. Build and run (Cmd+R)

## AI Setup (Osaurus)

Tweaks uses a minimal client (`Osaurus.swift`) to call a chat-completions style API to improve your text. By default it points to `http://localhost:1337` and expects an OpenAI-compatible endpoint at `/v1/chat/completions`.

Configure the endpoint and optional API key via environment variables (recommended during development):

1. In Xcode: Product → Scheme → Edit Scheme… → Run → Arguments → Environment Variables
2. Add entries:
   - `OSAURUS_BASE_URL` = `http://localhost:1337` (or your server URL)

Quick sanity check (replace values as needed):

```bash
curl -s "$OSAURUS_BASE_URL/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $OSAURUS_API_KEY" \
  -d '{
        "model": "llama-3.2-3b-instruct-4bit",
        "messages": [
          {"role":"system","content":"You are Osaurus Tweak. Improve the text."},
          {"role":"user","content":"Please improve this sentence."}
        ],
        "temperature": 0.3
      }'
```

Notes:

- If `OSAURUS_BASE_URL` is not set, Tweaks defaults to `http://localhost:1337`.
- The server must return an OpenAI-style response with `choices[0].message.content`.

## Development

For developers, we've included tools to make debugging easier:

- **Debug Tab**: One-click accessibility setup for each build
- **Visual Feedback**: Toast notifications and status indicators
- **Development Script**: Run `./dev_setup.sh` for guided setup

See [DEBUG_SETUP.md](DEBUG_SETUP.md) for detailed development instructions.

## Requirements

- macOS 14.0 or later
- Xcode 16.0 or later
- Accessibility permission (for hotkey functionality)
- OpenAI-compatible chat completions API (default: `http://localhost:1337`), or set `OSAURUS_BASE_URL`

## Usage

1. **First Run**: Grant accessibility permission when prompted
2. **Use Hotkey**: Press `Control+T` to paste AI‑improved clipboard text
3. **Customize**: Click the menu bar icon → Settings to change hotkey

Behavior details:

- Tweaks reads your clipboard, sends it to your configured AI endpoint, and temporarily replaces your clipboard with the improved text.
- It then presses `Cmd+V` for you to paste in the foreground app and restores your original clipboard shortly after.
- If the AI call fails, Tweaks falls back to pasting your original clipboard unchanged.

## Architecture

The project is organized for simplicity:

```
tweaks/
├── tweaksApp.swift          # App entry point
├── AppDelegate.swift        # Menu bar and hotkey handling
├── ContentView.swift        # Main UI with tabs
├── PermissionManager.swift  # Permission state management
├── HotkeyFeedback.swift    # Visual/audio feedback
├── Osaurus.swift            # Minimal OpenAI-compatible client and tweak helper
└── DebugHelpers.swift      # Debug-only utilities
```

### AI internals

- `Osaurus.Defaults` sets the default `model`, `systemPrompt`, and `temperature` used for tweaks. Advanced users can change these in code.

## License

This project is provided as-is for educational purposes.

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
