#!/bin/bash
set -e

echo "=========================================================="
echo "=== Robust Samsung A04 ROM Customizer (Multi-LZ4) ==="
echo "=========================================================="

mkdir -p work_dir
mkdir -p build_output

# 1. فك ضغط الأرشيف الأساسي
echo "[*] Extracting base firmware/AP archive..."
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

# 2. فك ضغط جميع ملفات lz4 الموجودة تلقائياً
echo "[*] Decompressing all lz4 compressed images..."
find work_dir/ -name "*.lz4" | while read -r lz4_file; do
    echo "Decompressing: $lz4_file"
    lz4 -d -q "$lz4_file" "${lz4_file%.lz4}" || true
done

# 3. البحث عن مسار نظام system أو system.img
SYS_IMG=$(find work_dir/ -name "system.img" | head -n 1)

if [ -n "$SYS_IMG" ]; then
    echo "[*] Found system.img directly at: $SYS_IMG"
    SYS_DIR=$(dirname "$SYS_IMG")
    
    # تعديل تطبيقات النظام مباشرة
    if [ -d "$SYS_DIR/system" ]; then
        TARGET_SYS="$SYS_DIR/system"
    else
        TARGET_SYS="$SYS_DIR"
    fi

    echo "[*] Applying debloat and customizations..."
    rm -rf "$TARGET_SYS/priv-app/GmsCore" 2>/dev/null || true
    rm -rf "$TARGET_SYS/priv-app/Phonesky" 2>/dev/null || true
    rm -rf "$TARGET_SYS/app/GoogleServicesFramework" 2>/dev/null || true

    # حقن Lawnchair
    mkdir -p "$TARGET_SYS/priv-app/Lawnchair"
    wget -O "$TARGET_SYS/priv-app/Lawnchair/Lawnchair.apk" "https://github.com/LawnchairLauncher/lawnchair/releases/download/v12.1-alpha.4/Lawnchair.apk" 2>/dev/null || true

    # تعديل build.prop
    BUILD_PROP=$(find work_dir/ -name "build.prop" | head -n 1)
    if [ -f "$BUILD_PROP" ]; then
        cat <<EOF >> "$BUILD_PROP"

# === Custom Tweaks & MicroG ===
ro.config.hw_fast_launch=true
persist.sys.ui.smooth=true
ro.build.signature_spoofing.enabled=true
persist.microg.support=true
EOF
    fi
fi

# 4. تجميع كافة الملفات الناتجة في أرشيف AP Odin النهائي
echo "[*] Packaging all files into Odin AP tar..."
mkdir -p output
# تجميع كل الملفات الفردية المستخرجة (بما فيها الصور المعدلة) لتشكل ملف AP متكامل
tar -cvf output/AP_CUSTOM_A04_MICROG.tar -C work_dir/ .

echo "=========================================================="
echo "🎉 Build Script Completed Successfully! 🎉"
echo "=========================================================="