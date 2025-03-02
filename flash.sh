#!/bin/sh
# Simplified ADV360PRO Firmware Updater
# Checks for dependencies
if ! command -v gum >/dev/null 2>&1; then
    echo "Error: gum is not installed. Please install it from https://github.com/charmbracelet/gum"
    exit 1
fi

# Configuration
GITHUB_REPO="Duffy1001/Adv360-Pro-ZMK"
TEMP_DIR="/tmp/adv360pro_firmware"

# Setup
rm -rf "$TEMP_DIR"
mkdir -p "$TEMP_DIR"

# Download firmware files
gum spin --spinner=dot --title="Getting Latest Release" --show-output -- curl -s "https://api.github.com/repos/$GITHUB_REPO/releases/latest" | 
    grep -o "https://.*\.uf2" | 
    while read url; do
        filename=$(basename "$url")
	gum spin --spinner=dot --title="$filename" -- curl -sL "$url" -o "$TEMP_DIR/$filename"
	echo "downloaded $filename"
    done

# Main loop
while true; do
    # Wait for keyboard
    gum spin --spinner=dot --title="Waiting for ADV360PRO keyboard... (Connect it in bootloader mode)" -- bash -c 'until ls /dev/disk/by-label/ADV360PRO* >/dev/null 2>&1; do sleep 1; done'
    # Get device info
    DEVICE_PATH=$(readlink -f /dev/disk/by-label/ADV360PRO*)
    MOUNT_POINT="/tmp/adv360pro_mount"
    mkdir -p "$MOUNT_POINT"
    
    # Mount
    echo "Mounting device..."
    mount "$DEVICE_PATH" "$MOUNT_POINT"
    
    # List firmware files
    UF2_FILES=$(find "$TEMP_DIR" -name "*.uf2" | sort)
    
    if [ -z "$UF2_FILES" ]; then
        echo "Error: No firmware files found."
        umount "$MOUNT_POINT"
        exit 1
    fi
    
    # Let user select firmware
    echo "Select firmware to flash:"
    FILE_LIST=""
    for file in $UF2_FILES; do
        FILE_LIST="$FILE_LIST$(basename "$file")\n"
    done
    
    SELECTED=$(echo -e "$FILE_LIST" | grep -v '^$' | gum choose)
    
    if [ -z "$SELECTED" ]; then
        echo "No file selected. Exiting."
        umount "$MOUNT_POINT"
        exit 0
    fi
    
    # Find selected file path
    for file in $UF2_FILES; do
        if [ "$(basename "$file")" = "$SELECTED" ]; then
            FIRMWARE_FILE="$file"
            break
        fi
    done
    
    # Determine if left or right side
    if echo "$SELECTED" | grep -q -i "left"; then
        TARGET_NAME="left.uf2"
    elif echo "$SELECTED" | grep -q -i "right"; then
        TARGET_NAME="right.uf2"
    else
        echo "Is this for the left or right side?"
        SIDE=$(gum choose "Left" "Right")
        TARGET_NAME=$(echo "$SIDE" | tr '[:upper:]' '[:lower:]').uf2
    fi
    
    # Flash the firmware
    echo "Flashing $SELECTED as $TARGET_NAME..."
    cp "$FIRMWARE_FILE" "$MOUNT_POINT/$TARGET_NAME"
    
    # Clean up
    echo "Unmounting device..."
    umount "$MOUNT_POINT"
    
    echo "✓ Firmware flashed successfully!"
    echo "The keyboard will restart automatically. Unplug When Complete."
    gum confirm "Run Again?" || break 
done
