# Tweaks - Debug Setup Guide

## Quick Start for Debug Builds

Every time you build in debug mode, macOS treats it as a new app that needs accessibility permissions. Here's the streamlined process:

### Method 1: Using the Debug Tab (Recommended)

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

### Method 2: Using the Debug Script

1. **Run the app** from Xcode
2. **Click the menu bar icon** (gear icon)
3. **Go to Debug tab**
4. **Click "Debug Script"**
   - This creates and runs a Terminal script that guides you through the process

### Method 3: Manual Process

1. Find your debug build location:
   ```
   ~/Library/Developer/Xcode/DerivedData/tweaks-*/Build/Products/Debug/tweaks.app
   ```
2. Open System Settings > Privacy & Security > Accessibility
3. Remove any old "tweaks" entries with "-" button
4. Click "+" and navigate to the path above
5. Toggle ON

## Verifying Hotkey Functionality

### Visual Feedback System

The app now includes comprehensive feedback:

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

## Project Structure

```
tweaks/
├── tweaksApp.swift          # Main app entry point
├── AppDelegate.swift        # Menu bar and hotkey handling
├── ContentView.swift        # Simplified main UI with tabs
├── PermissionManager.swift  # Centralized permission handling
├── HotkeyFeedback.swift    # Visual/audio feedback system
├── DebugHelpers.swift      # Debug-specific utilities
└── Info.plist              # App configuration
```

## Key Improvements

1. **Simplified UI**: Three tabs (Main, Settings, Debug) with focused functionality
2. **Clear Permission Flow**: Single source of truth for accessibility status
3. **Better Feedback**: Visual indicators, toast notifications, and test features
4. **Debug Helpers**: One-click setup for each debug build
5. **Reproducible Steps**: Consistent process that works every time

## Troubleshooting

### "Permission Required" Won't Go Away

1. Ensure you're granting permission to the exact build path
2. Try quitting and reopening the app after granting permission
3. Use the "Quit & Reopen" button in Debug tab

### Hotkey Not Working

1. Check the visual indicator in the top-right of the popover
2. Use "Test Hotkey Now" button to verify functionality
3. Ensure no other apps are using the same hotkey combination

### Debug Build Path Changed

This happens when Xcode creates a new DerivedData folder:

1. Use the Debug tab's "Setup Accessibility" button
2. It automatically handles the new path

## Development Tips

1. **Keep the Debug tab open** during development for quick access
2. **Use the feedback system** to verify changes immediately
3. **The app remembers** your custom hotkey between launches
4. **Visual feedback** appears even without clipboard content

## Default Hotkey

- **Control + T**: Paste clipboard text with 😊 emoji appended

Change it in Settings tab by clicking "Change" and pressing your desired combination.
