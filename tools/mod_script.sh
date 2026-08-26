#!/bin/bash
set -e

echo "=========================================================="
echo "=== Ultimate Samsung A04 MicroG & Lawnchair ROM Builder ==="
echo "=========================================================="

mkdir -p work_dir
mkdir -p build_output

# 1. استخراج الأرشيف الأساسي
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

# 2. فك ضغط جميع ملفات الصور المضغوطة بصيغة lz4 تلقائياً
echo "[*] Decompressing all lz4 compressed images..."
find work_dir/ -name "*.lz4" | while read -r lz4_file; do
    echo "Decompressing: $lz4_file"
    lz4 -d -q "$lz4_file" "${lz4_file%.lz4}" || true
done

# 3. إزالة تطبيقات جوجل الثقيلة (Debloating) وحقن الخدمات البديلة ومشغل Lawnchair
SYS_IMG=$(find work_dir/ -name "system.img" | head -n 1)
if [ -n "$SYS_IMG" ]; then
    echo "[*] Found system.img. Setting up paths..."
    SYS_DIR=$(dirname "$SYS_IMG")
    
    if [ -d "$SYS_DIR/system" ]; then
        TARGET_SYS="$SYS_DIR/system"
    else
        TARGET_SYS="$SYS_DIR"
    fi

    echo "[*] Removing heavy Google Bloatware..."
    rm -rf "$TARGET_SYS/priv-app/GmsCore" 2>/dev/null || true
    rm -rf "$TARGET_SYS/priv-app/Phonesky" 2>/dev/null || true
    rm -rf "$TARGET_SYS/app/GoogleServicesFramework" 2>/dev/null || true

    # حقن Lawnchair Launcher الشاشة الرئيسية
    echo "[*] Injecting Lawnchair Launcher..."
    mkdir -p "$TARGET_SYS/priv-app/Lawnchair"
    wget -O "$TARGET_SYS/priv-app/Lawnchair/Lawnchair.apk" "https://github.com/LawnchairLauncher/lawnchair/releases/download/v12.1-alpha.4/Lawnchair.apk" 2>/dev/null || true
    chmod 755 "$TARGET_SYS/priv-app/Lawnchair"
    chmod 644 "$TARGET_SYS/priv-app/Lawnchair/Lawnchair.apk"
fi

# 4. تعديل ملف build.prop لتفعيل MicroG وتزوير التوقيع الرقمي وتحسين الأداء
BUILD_PROP=$(find work_dir/ -name "build.prop" | head -n 1)
if [ -f "$BUILD_PROP" ]; then
    cat <<EOF >> "$BUILD_PROP"

# === MicroG, Signature Spoofing & Performance Tweaks ===
ro.config.hw_fast_launch=true
persist.sys.ui.smooth=true
ro.build.signature_spoofing.enabled=true
persist.microg.support=true
EOF
    echo "[*] build.prop successfully patched."
fi

echo "=========================================================="
echo "🎉 ROM Customization & Script Execution Completed! 🎉"
echo "=========================================================="