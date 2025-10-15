#!/bin/bash

# Setup script for ePOS2 native libraries
# Run this after downloading the complete ePOS2 SDK from Epson

echo "🔧 Setting up ePOS2 native libraries..."

# Check if SDK directory exists
if [ ! -d "epos2_sdk" ]; then
    echo "❌ epos2_sdk directory not found!"
    echo "Please download the complete ePOS2 SDK and extract it to 'epos2_sdk' directory"
    echo "Download from: https://download4.epson.biz/sec_pubs/pos/reference_en/epos_android/"
    exit 1
fi

# Create jniLibs directories
echo "📁 Creating jniLibs directories..."
mkdir -p android/app/src/main/jniLibs/arm64-v8a
mkdir -p android/app/src/main/jniLibs/armeabi-v7a
mkdir -p android/app/src/main/jniLibs/x86
mkdir -p android/app/src/main/jniLibs/x86_64

# Copy native libraries
echo "📋 Copying native libraries..."

# Try different possible SDK structures
if [ -f "epos2_sdk/libs/arm64-v8a/libepos2.so" ]; then
    cp epos2_sdk/libs/arm64-v8a/libepos2.so android/app/src/main/jniLibs/arm64-v8a/
    cp epos2_sdk/libs/armeabi-v7a/libepos2.so android/app/src/main/jniLibs/armeabi-v7a/
    cp epos2_sdk/libs/x86/libepos2.so android/app/src/main/jniLibs/x86/
    cp epos2_sdk/libs/x86_64/libepos2.so android/app/src/main/jniLibs/x86_64/
elif [ -f "epos2_sdk/arm64-v8a/libepos2.so" ]; then
    cp epos2_sdk/arm64-v8a/libepos2.so android/app/src/main/jniLibs/arm64-v8a/
    cp epos2_sdk/armeabi-v7a/libepos2.so android/app/src/main/jniLibs/armeabi-v7a/
    cp epos2_sdk/x86/libepos2.so android/app/src/main/jniLibs/x86/
    cp epos2_sdk/x86_64/libepos2.so android/app/src/main/jniLibs/x86_64/
else
    echo "❌ Could not find libepos2.so files in epos2_sdk directory"
    echo "Please check the SDK structure and adjust the paths in this script"
    exit 1
fi

echo "✅ Native libraries copied successfully!"
echo "🚀 You can now run: flutter run"
echo ""
echo "Expected result:"
echo "- App should connect to Epson printer successfully"
echo "- Green printer icon should appear"
echo "- Barcode printing should work"
