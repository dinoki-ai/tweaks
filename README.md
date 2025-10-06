# Tweaks 🎯

A simple macOS menu bar app that adds emoji to your clipboard text when pasting.

## Features

- **Global Hotkey**: Press `Control+T` (customizable) to paste text with an emoji
- **Menu Bar App**: Lives quietly in your menu bar
- **Visual Feedback**: See when hotkeys are triggered
- **Easy Setup**: Clear onboarding for accessibility permissions

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

- macOS 14.0 or later
- Xcode 16.0 or later
- Accessibility permission (for hotkey functionality)

## Usage

1. **First Run**: Grant accessibility permission when prompted
2. **Use Hotkey**: Press `Control+T` to paste text with 😊 emoji
3. **Customize**: Click the menu bar icon → Settings to change hotkey

## Architecture

The project is organized for simplicity:

```
tweaks/
├── tweaksApp.swift          # App entry point
├── AppDelegate.swift        # Menu bar and hotkey handling
├── ContentView.swift        # Main UI with tabs
├── PermissionManager.swift  # Permission state management
├── HotkeyFeedback.swift    # Visual/audio feedback
└── DebugHelpers.swift      # Debug-only utilities
```

## License

This project is provided as-is for educational purposes.
