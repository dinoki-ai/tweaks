# Sparkle Auto-Update Setup

This document describes how Sparkle auto-update is configured for Tweaks, matching the Osaurus implementation pattern.

## Overview

Tweaks uses [Sparkle](https://sparkle-project.org/) 2.7.0 for automatic updates, with EdDSA signatures for security.

## Initial Setup

### 1. Generate Keys

First time only - generate your EdDSA key pair:

```bash
./scripts/generate_sparkle_keys.sh
```

This will:

- Download Sparkle tools
- Generate an EdDSA key pair
- Display both public and private keys

### 2. Configure Keys

1. **Public Key**: Replace `TO_BE_REPLACED_WITH_PUBLIC_KEY` in `tweaks/Info.plist` with your public key
2. **Private Key**:
   - Add as `SPARKLE_PRIVATE_KEY` secret in GitHub repository settings
   - Store securely in your password manager
   - NEVER commit to repository

### 3. GitHub Configuration

In your GitHub repository:

1. Go to Settings → Secrets and variables → Actions
2. Add repository secret: `SPARKLE_PRIVATE_KEY` (your private key)
3. Ensure GitHub Pages is enabled for the `main` branch `/docs` folder

## Architecture

### Components

1. **SparkleManager.swift**: Main update manager class

   - Singleton pattern for app-wide access
   - Observable for SwiftUI integration
   - Handles update checking and user preferences

2. **Info.plist Configuration**:

   - `SUFeedURL`: Points to GitHub Pages hosted appcast.xml
   - `SUEnableAutomaticChecks`: Default enabled
   - `SUPublicEDKey`: Your public key for signature verification

3. **Update UI**: Integrated in SystemSettingsView
   - Toggle for automatic updates
   - Manual check button
   - Status display

### Build & Release Process

1. **Build Scripts**:

   - `create_dmgs.sh`: Creates distribution DMG
   - `notarize.sh`: Apple notarization
   - `generate_and_deploy_appcast.sh`: Creates Sparkle appcast

2. **Release Workflow**:

   - Tag push triggers build
   - DMG created and notarized
   - Appcast generated with EdDSA signature
   - Published to GitHub Pages

3. **Update Distribution**:
   - Appcast served from: `https://dinoki-ai.github.io/tweaks/appcast.xml`
   - DMGs hosted as GitHub release assets
   - Release notes in HTML format

## Testing Updates

1. **Local Testing**:

   ```bash
   # Build and notarize
   ./scripts/build_arm64.sh
   ./scripts/create_dmgs.sh

   # Test appcast generation
   SPARKLE_PRIVATE_KEY="your-key" VERSION="1.0.1" ./scripts/generate_and_deploy_appcast.sh
   ```

2. **Update Flow**:
   - App checks appcast.xml periodically
   - Downloads update if newer version found
   - Verifies EdDSA signature
   - Prompts user to install

## Troubleshooting

### Common Issues

1. **"Updates not available"**:

   - Check SUFeedURL in Info.plist
   - Verify appcast.xml is accessible
   - Ensure public key matches private key

2. **Signature verification failed**:

   - Regenerate keys if needed
   - Ensure SPARKLE_PRIVATE_KEY is correctly set
   - Check appcast.xml has edSignature attribute

3. **Build errors**:
   - Clean build folder
   - Reset Swift Package caches
   - Ensure Sparkle 2.7.0 is downloaded

### Debug Mode

Enable Sparkle verbose logging:

```bash
defaults write com.dinoki.tweaks SUEnableAutomaticChecks -bool YES
defaults write com.dinoki.tweaks SUScheduledCheckInterval -int 3600
```

## Security Notes

- EdDSA signatures prevent tampering
- HTTPS distribution recommended
- Private key must remain secret
- Notarization required for macOS distribution

## References

- [Sparkle Documentation](https://sparkle-project.org/documentation/)
- [Osaurus Implementation](https://github.com/dinoki-ai/osaurus)
