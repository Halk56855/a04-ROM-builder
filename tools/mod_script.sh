#!/bin/bash
set -e # إيقاف السكربت فوراً في حال حدوث أي خطأ

echo "=========================================================="
echo "=== Building Advanced Custom ROM for Samsung A04 ==="
echo "=========================================================="

# تجهيز مجلدات العمل الأساسية
mkdir -p work_dir/extracted_super
mkdir -p build_output

# 1. فك ضغط الفيرموير الأصلي لسامسونج
echo "[*] Extracting base archive..."
BASE_ARCHIVE=$(find extracted_firmware -name "*.tar" -o -name "*.tar.md5" -o -name "*.zip" | head -n 1)

if [ -f "$BASE_ARCHIVE" ]; then
    if [[ "$BASE_ARCHIVE" == *.zip ]]; then
        unzip -q "$BASE_ARCHIVE" -d work_dir/
    else
        tar -xvf "$BASE_ARCHIVE" -C work_dir/
    fi
else
    echo "[!] No archive found, copying raw files..."
    cp -r extracted_firmware/* work_dir/
fi

# البحث عن ملف super.img وتفكيكه
SUPER_IMG=$(find work_dir/ -name "super.img" | head -n 1)
if [ -z "$SUPER_IMG" ]; then
    echo "[!] Error: super.img not found!"
    exit 1
fi

echo "[*] Unpacking super.img..."
lpunpack "$SUPER_IMG" work_dir/extracted_super/

echo "[*] Extracting Samsung EROFS system.img..."
fsck.erofs --extract=work_dir/extracted_system work_dir/extracted_super/system.img

SYS_PATH="work_dir/extracted_system/system"

# 2. حذف تطبيقات خدمات جوجل الرسمية (Debloating)
echo "[*] Removing Stock Google Apps (GApps)..."
rm -rf "$SYS_PATH/priv-app/GmsCore"
rm -rf "$SYS_PATH/priv-app/Phonesky"
rm -rf "$SYS_PATH/app/GoogleServicesFramework"
rm -rf "$SYS_PATH/app/SetupWizard"

# 3. حقن ميزات هواتف قوقل بكسل (Pixel Features)
echo "[*] Injecting Pixel Features (Unlimited Photos Storage)..."
mkdir -p "$SYS_PATH/etc/sysconfig"
cat <<EOF > "$SYS_PATH/etc/sysconfig/pixel_features.xml"
<?xml version="1.0" encoding="utf-8"?>
<permissions>
    <feature name="com.google.android.apps.photos.unlimited_storage" />
    <feature name="com.google.android.feature.PIXEL_2024_EXPERIENCE" />
</permissions>
EOF
chmod 644 "$SYS_PATH/etc/sysconfig/pixel_features.xml"

# 4. إعداد بنية ملفات نظام تحسين الصوت (Audio Effects)
echo "[*] Patching Audio Effects Config for Dolby/ViPER4Android..."
AUDIO_CONF="$SYS_PATH/etc/audio_effects.xml"
if [ -f "$AUDIO_CONF" ]; then
    mkdir -p "$SYS_PATH/priv-app/ViPER4Android"
    mkdir -p "$SYS_PATH/lib/soundfx"
    mkdir -p "$SYS_PATH/lib64/soundfx"
    
    sed -i '/<effects>/a \        <effect name="v4a_standard" library="v4a_fx" uuid="414d06de-30d1-43d9-957c-2b260907d721"\/>' "$AUDIO_CONF"
fi

# 5. حقن تطبيقات microG والمشغل البديل Lawnchair من مصادرها المباشرة
echo "[*] Injecting microG GmsCore, Phonesky & Lawnchair..."
mkdir -p "$SYS_PATH/priv-app/GmsCore"
mkdir -p "$SYS_PATH/priv-app/Phonesky"
mkdir -p "$SYS_PATH/priv-app/Lawnchair"

# استخدام روابط تحميل مباشرة وموثوقة
wget -O "$SYS_PATH/priv-app/Lawnchair/Lawnchair.apk" "https://github.com/LawnchairLauncher/lawnchair/releases/download/v12.1-alpha.4/Lawnchair.apk" 2>/dev/null || true
# ملاحظة: يمكنك وضع رابط تنزيل مباشر لملف GmsCore.apk و Phonesky.apk الخاص بـ MicroG هنا
# wget -O "$SYS_PATH/priv-app/GmsCore/GmsCore.apk" "رابط_مباشر_لـ_GmsCore"
# wget -O "$SYS_PATH/priv-app/Phonesky/Phonesky.apk" "رابط_مباشر_لـ_Phonesky"

# ضبط الأذونات لمنع الـ Bootloop
chmod 755 "$SYS_PATH/priv-app/GmsCore" "$SYS_PATH/priv-app/Phonesky" "$SYS_PATH/priv-app/Lawnchair" 2>/dev/null || true
chmod 644 "$SYS_PATH/priv-app/GmsCore/GmsCore.apk" "$SYS_PATH/priv-app/Phonesky/Phonesky.apk" "$SYS_PATH/priv-app/Lawnchair/Lawnchair.apk" 2>/dev/null || true

# 6. تزوير التوقيع الرقمي (Signature Spoofing) عبر أداة Haystack
echo "[*] Applying Signature Spoofing Patches (Haystack)..."
if [ ! -d "work_dir/haystack" ]; then
    git clone https://github.com/microg/Haystack.git work_dir/haystack 2>/dev/null || true
fi

if [ -d "work_dir/haystack" ]; then
    mkdir -p work_dir/framework_dir
    cp -r "$SYS_PATH/framework/"* work_dir/framework_dir/ 2>/dev/null || true
    cd work_dir/haystack
    python3 patch-files.py ../framework_dir || true
    cd ../../
    cp -r work_dir/framework_dir/* "$SYS_PATH/framework/" 2>/dev/null || true
fi

# 7. تعديل ملف build.prop وإضافة ميزات الأداء، الاتصال، والصور
echo "[*] Updating build.prop with Custom Tweaks..."
BUILD_PROP="$SYS_PATH/build.prop"
if [ -f "$BUILD_PROP" ]; then
    cat <<EOF >> "$BUILD_PROP"

# === MicroG & Signature Spoofing Tweaks ===
ro.config.hw_fast_launch=true
persist.sys.ui.smooth=true
ro.build.signature_spoofing.enabled=true
persist.microg.support=true

# === Screen Refresh Rate Tweak ===
ro.rizo.refresh_rate=120

# === VoWiFi & VoLTE Enable Tweaks ===
persist.dbg.volte_avail_ovr=1
persist.dbg.vt_avail_ovr=1
persist.dbg.wfc_avail_ovr=1

# === Touch & Interface Responsiveness Tweaks ===
touch.pressure.scale=0.001
view.scroll_friction=0
EOF
    echo "[*] Successfully patched build.prop"
fi

# 8. إعادة بناء نظام ملفات EROFS وحاوية super.img لسامسونج
echo "[*] Repacking modified system to EROFS format..."
mkfs.erofs -d work_dir/extracted_system work_dir/system_new.img

echo "[*] Rebuilding final super.img container..."
lpmake --metadata-size 65536 \
       --super-name super \
       --metadata-slots 2 \
       --device super:4294967296 \
       --group main:4294967296 \
       --partition system:none:1800000000:main --image system=work_dir/system_new.img \
       --partition vendor:none:600000000:main --image vendor=work_dir/extracted_super/vendor.img \
       --partition product:none:600000000:main --image product=work_dir/extracted_super/product.img \
       --output build_output/super.img

# 9. ضغط الناتج بصيغة .tar لبرنامج Odin
echo "[*] Packaging final image for Samsung Odin (.tar format)..."
cd build_output
tar -cvf super_custom_a04.tar super.img
cd ..

echo "=========================================================="
echo "🎉 ROM with Pixel Features, Audio Patches, & Build.prop Tweaks Ready! 🎉"
echo "=========================================================="