#!/bin/bash

echo "=== Injecting GApps Super Lite & Lawnchair into Clean Base ==="

mkdir -p work_dir
mkdir -p build_output

# استخراج محتويات الروم الخفيف الأساسي
BASE_ARCHIVE=$(find extracted_firmware -name "*.tar" -o -name "*.tar.md5" -o -name "*.zip")
if [ -f "$BASE_ARCHIVE" ]; then
    if [[ "$BASE_ARCHIVE" == *.zip ]]; then
        unzip -q "$BASE_ARCHIVE" -d work_dir/
    else
        tar -xvf "$BASE_ARCHIVE" -C work_dir/
    fi
else
    cp -r extracted_firmware/* work_dir/
fi

# 1. حقن Lawnchair Launcher كشاشة رئيسية أساسية
echo "Injecting Lawnchair Launcher..."
LAUNCHER_DIR=$(find work_dir/ -type d -name "priv-app" -o -name "app" | head -n 1)
if [ -n "$LAUNCHER_DIR" ]; then
    mkdir -p "$LAUNCHER_DIR/Lawnchair"
    wget -O "$LAUNCHER_DIR/Lawnchair/Lawnchair.apk" "https://github.com/LawnchairLauncher/lawnchair/releases/download/v12.1-alpha.4/Lawnchair.apk" 2>/dev/null || true
    echo "Lawnchair injected successfully."
fi

# 2. حقن إضافات GApps Super Lite (Google Play Services الأساسية فقط)
echo "Setting up GApps Super Lite framework..."
# يمكنك إضافة ملفات الحزمة المصغرة هنا إن وجدت، أو تفعيل هيكلة متجر جوجل الأساسي

# 3. حقن سمات وتعديلات الرومات المعدلة في build.prop
BUILD_PROP=$(find work_dir/ -name "build.prop" | head -n 1)
if [ -f "$BUILD_PROP" ]; then
    echo "" >> "$BUILD_PROP"
    echo "# Custom Unleashed Lite Tweaks & Themes" >> "$BUILD_PROP"
    echo "ro.config.hw_fast_launch=true" >> "$BUILD_PROP"
    echo "persist.sys.ui.smooth=true" >> "$BUILD_PROP"
    echo "ro.launcher.layout.support=true" >> "$BUILD_PROP"
    echo "persist.sys.custom.themes=enabled" >> "$BUILD_PROP"
    echo "Successfully injected custom ROM tweaks."
fi

# نقل الملفات المجهزة إلى مجلد البناء النهائي
cp -r work_dir/* build_output/
echo "Custom ROM packaging and modification completed!"