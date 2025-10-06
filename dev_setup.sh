#!/bin/bash
# Development Setup Helper for Tweaks

echo "🔧 Tweaks Development Helper"
echo "=========================="
echo ""

# Function to get the latest debug build path
get_debug_path() {
    find ~/Library/Developer/Xcode/DerivedData -name "tweaks.app" -path "*/Debug/*" -type d -print0 2>/dev/null | xargs -0 ls -td | head -n1
}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Main menu
show_menu() {
    echo "What would you like to do?"
    echo ""
    echo "1) Open Accessibility Settings & Copy App Path"
    echo "2) Build & Run in Xcode"
    echo "3) Check Accessibility Status"
    echo "4) Clean Build Folder"
    echo "5) View Debug Setup Guide"
    echo "6) Exit"
    echo ""
}

# Check if app has accessibility permission
check_accessibility() {
    APP_PATH=$(get_debug_path)
    if [ -z "$APP_PATH" ]; then
        echo -e "${RED}❌ No debug build found. Build the app first.${NC}"
        return
    fi
    
    # This is a simplified check - actual permission check would require running the app
    echo -e "${YELLOW}📍 Current debug build:${NC}"
    echo "$APP_PATH"
    echo ""
    echo "To verify accessibility:"
    echo "1. Run the app from Xcode"
    echo "2. Click the gear icon in menu bar"
    echo "3. Check the status indicator (green = enabled)"
}

# Main loop
while true; do
    show_menu
    read -p "Select option (1-6): " choice
    echo ""
    
    case $choice in
        1)
            APP_PATH=$(get_debug_path)
            if [ -z "$APP_PATH" ]; then
                echo -e "${RED}❌ No debug build found. Build the app first.${NC}"
            else
                echo "$APP_PATH" | pbcopy
                echo -e "${GREEN}✅ App path copied to clipboard!${NC}"
                echo ""
                echo "Opening Accessibility settings..."
                open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                echo ""
                echo "Instructions:"
                echo "1. Click the '+' button"
                echo "2. Press Cmd+V to paste the path"
                echo "3. Select the app and click 'Open'"
                echo "4. Toggle the switch ON"
            fi
            ;;
        2)
            echo "Building and running in Xcode..."
            open /Users/tpae/dev/tweaks/tweaks.xcodeproj
            echo -e "${YELLOW}⚡ Xcode will open. Press Cmd+R to build and run.${NC}"
            ;;
        3)
            check_accessibility
            ;;
        4)
            echo "Cleaning build folder..."
            xcodebuild -project /Users/tpae/dev/tweaks/tweaks.xcodeproj -scheme tweaks clean
            echo -e "${GREEN}✅ Build folder cleaned!${NC}"
            ;;
        5)
            echo "Opening debug setup guide..."
            if [ -f "/Users/tpae/dev/tweaks/DEBUG_SETUP.md" ]; then
                open "/Users/tpae/dev/tweaks/DEBUG_SETUP.md"
            else
                echo -e "${RED}❌ DEBUG_SETUP.md not found${NC}"
            fi
            ;;
        6)
            echo "Goodbye! 👋"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid option. Please try again.${NC}"
            ;;
    esac
    
    echo ""
    echo "Press Enter to continue..."
    read
    clear
done
