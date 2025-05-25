#!/bin/bash

# Define the download URL and target directory
DOWNLOAD_URL="https://raw.githubusercontent.com/lhxx889/-/main/crypto_monitor_final.zip"
TARGET_DIR="$HOME/crypto_monitor"
ZIP_FILE_NAME="crypto_monitor_final.zip"
INSTALL_SCRIPT_NAME="super_simple_installer_v3.sh"

# Create target directory if it doesn't exist
mkdir -p "$TARGET_DIR"

# Navigate to the target directory or exit if failed
cd "$TARGET_DIR" || { echo "Failed to navigate to $TARGET_DIR. Exiting."; exit 1; }

# Download the zip file
echo "Downloading $ZIP_FILE_NAME..."
wget -q "$DOWNLOAD_URL" -O "$ZIP_FILE_NAME"
if [ $? -ne 0 ]; then
    echo "Failed to download $ZIP_FILE_NAME. Exiting."
    exit 1
fi
echo "Download complete."

# Unzip the downloaded file
echo "Unzipping $ZIP_FILE_NAME..."
unzip -o "$ZIP_FILE_NAME" -d "$TARGET_DIR" # Use -o to overwrite existing files without prompting
if [ $? -ne 0 ]; then
    echo "Failed to unzip $ZIP_FILE_NAME. Exiting."
    exit 1
fi
echo "Unzip complete."

# Make the installation script executable
INSTALL_SCRIPT_PATH="$TARGET_DIR/$INSTALL_SCRIPT_NAME"
if [ -f "$INSTALL_SCRIPT_PATH" ]; then
    echo "Making $INSTALL_SCRIPT_NAME executable..."
    chmod +x "$INSTALL_SCRIPT_PATH"
    if [ $? -ne 0 ]; then
        echo "Failed to make $INSTALL_SCRIPT_NAME executable. Exiting."
        exit 1
    fi
    echo "$INSTALL_SCRIPT_NAME is now executable."
else
    echo "Installation script $INSTALL_SCRIPT_PATH not found. Exiting."
    exit 1
fi

# Run the installation script
echo "Running $INSTALL_SCRIPT_NAME..."
"$INSTALL_SCRIPT_PATH"
if [ $? -ne 0 ]; then
    echo "Installation script failed. Exiting."
    exit 1
fi

echo "Crypto Monitor installation completed successfully!"
exit 0
