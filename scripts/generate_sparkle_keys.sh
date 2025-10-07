#!/usr/bin/env bash
set -euo pipefail

echo "🔐 Generating Sparkle EdDSA key pair..."

# Create a temporary directory for Sparkle tools
mkdir -p sparkle_tools
cd sparkle_tools

# Download Sparkle if not already present
if [ ! -f "bin/generate_keys" ]; then
  echo "📥 Downloading Sparkle tools..."
  curl -L -o sparkle.tar.xz "https://github.com/sparkle-project/Sparkle/releases/download/2.7.0/Sparkle-2.7.0.tar.xz"
  tar -xf sparkle.tar.xz
  chmod +x bin/generate_keys
fi

# Generate keys
echo "🔑 Generating EdDSA key pair..."
./bin/generate_keys

echo ""
echo "⚠️  IMPORTANT: Key Storage Instructions"
echo "======================================="
echo ""
echo "1. Copy the PRIVATE KEY to your secure storage (password manager, etc.)"
echo "   - This key is used for signing updates"
echo "   - Add it as SPARKLE_PRIVATE_KEY secret in GitHub repository settings"
echo "   - NEVER commit this key to your repository!"
echo ""
echo "2. The PUBLIC KEY should be added to Info.plist:"
echo "   - Replace 'TO_BE_REPLACED_WITH_PUBLIC_KEY' in Info.plist with the public key shown above"
echo "   - This key can be safely committed to your repository"
echo ""
echo "3. For GitHub Actions:"
echo "   - Go to Settings → Secrets and variables → Actions"
echo "   - Add new repository secret named SPARKLE_PRIVATE_KEY"
echo "   - Paste the PRIVATE KEY value (the base64 string)"
echo ""
echo "✅ Key generation complete!"
