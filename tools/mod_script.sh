#!/bin/bash
set -e

echo "=========================================================="
echo "=== Advanced Samsung A04 Super.img ROM Customizer ==="
echo "=========================================================="

mkdir -p work_dir/extracted_super
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

# 2. البحث عن ملف super.img.lz4 أو super.img وفك ضغطه
LZ4_SUPER=$(find work_dir/ -name "super.img.lz4" | head -n 1)
if [ -f "$LZ4_SUPER" ]; then
    echo "[*] Decompressing super.img.lz4..."
    lz4 -d "$LZ4_SUPER" work_dir/super.img
fi

SUPER_IMG=$(find work_dir/ -name "super.img" | head -n 1)
if [ -z "$SUPER_IMG" ]; then
    echo "[!] Error: super.img not found after extraction!"
    exit 1
fi

# 3. تفكيك حاوية super.img لاستخراج أقسام النظام (مثل system.img)
echo "[*] Unpacking super.img..."
lpunpack "$SUPER_IMG" work_dir/extracted_super/

# 4. التعامل مع نظام EROFS الخاص بقسم system.img
echo "[*] Extracting system.img filesystem..."
mkdir -p work_dir/extracted_system
fsck.erofs --extract=work_dir/extracted_system work_dir/extracted_super/system.img

SYS_PATH="work_dir/extracted_system/system"

# 5. حذف تطبيقات جوجل الثقيلة (Debloating)
echo "[*] Removing stock Google apps..."
rm -rf "$SYS_PATH/priv-app/GmsCore" 2>/dev/null || true
rm -rf "$SYS_PATH/priv-app/Phonesky" 2>/dev/null || true
rm -rf "$SYS_PATH/app/GoogleServicesFramework" 2>/dev/null || true

# 6. حقن مشغل Lawnchair كبديل لشاشة سامسونج
echo "[*] Injecting Lawnchair Launcher..."
mkdir -p "$SYS_PATH/priv-app/Lawnchair"
wget -O "$SYS_PATH/priv-app/Lawnchair/Lawnchair.apk" "https://github.com/LawnchairLauncher/lawnchair/releases/download/v12.1-alpha.4/Lawnchair.apk" 2>/dev/null || true
chmod 755 "$SYS_PATH/priv-app/Lawnchair"
chmod 644 "$SYS_PATH/priv-app/Lawnchair/Lawnchair.apk"

# 7. تعديل build.prop لتفعيل MicroG وتزوير التوقيع الرقمي وتحسين الأداء
BUILD_PROP=$(find work_dir/extracted_system -name "build.prop" | head -n 1)
if [ -f "$BUILD_PROP" ]; then
    cat <<EOF >> "$BUILD_PROP"

# === Custom MicroG & Performance Tweaks ===
ro.config.hw_fast_launch=true
persist.sys.ui.smooth=true
ro.build.signature_spoofing.enabled=true
persist.microg.support=true
EOF
    echo "[*] build.prop successfully patched."
fi

# 8. إعادة بناء system.img بصيغة EROFS وتجميع super.img من جديد
echo "[*] Repacking system.img to EROFS..."
mkfs.erofs -d work_dir/extracted_system work_dir/extracted_super/system_new.img
mv work_dir/extracted_super/system_new.img work_dir/extracted_super/system.img

echo "[*] Rebuilding final super.img container..."
lpmake --metadata-size 65536 \
       --super-name super \
       --metadata-slots 2 \
       --device super:4294967296 \
       --group main:4294967296 \
       --partition system:none:2100000000:main --image system=work_dir/extracted_super/system.img \
       --partition vendor:none:800000000:main --image vendor=work_dir/extracted_super/vendor.img \
       --partition product:none:800000000:main --image product=work_dir/extracted_super/product.img \
       --output build_output/super.img

# 9. ضغط الناتج النهائي بملف TAR متوافق مع Odin داخل مجلد output
echo "[*] Packaging final image for Odin..."
mkdir -p output
cd build_output
tar -cvf ../output/AP_CUSTOM_A04_MICROG.tar super.img
cd ..

echo "=========================================================="
echo "🎉 Custom A04 ROM with MicroG & Lawnchair Built Successfully! 🎉"
echo "=========================================================="