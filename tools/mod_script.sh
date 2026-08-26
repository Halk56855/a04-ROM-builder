#!/bin/bash
set -e

echo "=========================================================="
echo "=== Fixing Odin Package Output for Samsung A04 ==="
echo "=========================================================="

mkdir -p work_dir
mkdir -p build_output

# 1. فك ضغط الفيرموير الأساسي
BASE_ARCHIVE=$(find extracted_firmware -name "*.tar" -o -name "*.tar.md5" -o -name "*.zip" | head -n 1)

if [ -f "$BASE_ARCHIVE" ]; then
    if [[ "$BASE_ARCHIVE" == *.zip ]]; then
        unzip -q "$BASE_ARCHIVE" -d work_dir/
    else
        tar -xvf "$BASE_ARCHIVE" -C work_dir/
    fi
else
    cp -r extracted_firmware/* work_dir/
fi

# البحث عن مسار النظام الحقيقي وتعديله
SYS_PATH=$(find work_dir/ -type d -name "system" | head -n 1)
if [ -z "$SYS_PATH" ]; then
    SYS_PATH="work_dir"
fi

# 2. حذف تطبيقات خدمات جوجل الرسمية وتطبيق التعديلات المطلوبة
echo "[*] Applying debloat and customizations..."
rm -rf "$SYS_PATH/priv-app/GmsCore" 2>/dev/null || true
rm -rf "$SYS_PATH/priv-app/Phonesky" 2>/dev/null || true

# حقن مشغل Lawnchair
LAUNCHER_DIR=$(find work_dir/ -type d -name "priv-app" -o -name "app" | head -n 1)
if [ -n "$LAUNCHER_DIR" ]; then
    mkdir -p "$LAUNCHER_DIR/Lawnchair"
    wget -O "$LAUNCHER_DIR/Lawnchair/Lawnchair.apk" "https://github.com/LawnchairLauncher/lawnchair/releases/download/v12.1-alpha.4/Lawnchair.apk" 2>/dev/null || true
fi

# 3. تعديل build.prop
BUILD_PROP=$(find work_dir/ -name "build.prop" | head -n 1)
if [ -f "$BUILD_PROP" ]; then
    cat <<EOF >> "$BUILD_PROP"

# === MicroG & Custom Tweaks ===
ro.config.hw_fast_launch=true
persist.sys.ui.smooth=true
ro.build.signature_spoofing.enabled=true
persist.microg.support=true
EOF
fi

# 4. نقل ونسخ محتويات work_dir بالكامل وبشكل صحيح إلى مجلد البناء النهائي
echo "[*] Preparing files for Odin package..."
cp -r work_dir/* build_output/
# تنظيف أي ملفات مضغوطة سابقة قد تسبب تداخل الحجم
rm -f build_output/*.zip build_output/*.tar 2>/dev/null || true

echo "=========================================================="
echo "🎉 Script execution finished successfully! 🎉"
echo "=========================================================="