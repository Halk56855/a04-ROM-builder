#!/bin/bash
set -e # إيقاف السكربت فوراً في حال حدوث أي خطأ

echo "=========================================================="
echo "=== Building Advanced Custom ROM for Samsung A04 ==="
echo "=========================================================="

# تجهيز مجلدات العمل الأساسية
mkdir -p work_dir
mkdir -p build_output

# 1. فك ضغط الفيرموير أو الروم الأساسي
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

# البحث عن مجلد النظام أو ملفات النظام مباشرة
SYS_PATH=$(find work_dir/ -type d -name "system" | head -n 1)
if [ -z "$SYS_PATH" ]; then
    # إذا لم يوجد مجلد نظام مباشر، نبحث عن أي مسار يحتوي على system
    SYS_PATH="work_dir/system"
    mkdir -p "$SYS_PATH"
fi

echo "[*] Target System Path located at: $SYS_PATH"

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

# 4. إعداد بنية ملفات نظام تحسين الصوت
echo "[*] Patching Audio Effects Config..."
AUDIO_CONF="$SYS_PATH/etc/audio_effects.xml"
if [ -f "$AUDIO_CONF" ]; then
    mkdir -p "$SYS_PATH/priv-app/ViPER4Android"
    mkdir -p "$SYS_PATH/lib/soundfx"
    mkdir -p "$SYS_PATH/lib64/soundfx"
    sed -i '/<effects>/a \        <effect name="v4a_standard" library="v4a_fx" uuid="414d06de-30d1-43d9-957c-2b260907d721"\/>' "$AUDIO_CONF" 2>/dev/null || true
fi

# 5. حقن تطبيقات microG والمشغل البديل Lawnchair
echo "[*] Injecting microG GmsCore, Phonesky & Lawnchair..."
mkdir -p "$SYS_PATH/priv-app/GmsCore"
mkdir -p "$SYS_PATH/priv-app/Phonesky"
mkdir -p "$SYS_PATH/priv-app/Lawnchair"

wget -O "$SYS_PATH/priv-app/Lawnchair/Lawnchair.apk" "https://github.com/LawnchairLauncher/lawnchair/releases/download/v12.1-alpha.4/Lawnchair.apk" 2>/dev/null || true

chmod 755 "$SYS_PATH/priv-app/GmsCore" "$SYS_PATH/priv-app/Phonesky" "$SYS_PATH/priv-app/Lawnchair" 2>/dev/null || true
chmod 644 "$SYS_PATH/priv-app/GmsCore/GmsCore.apk" "$SYS_PATH/priv-app/Phonesky/Phonesky.apk" "$SYS_PATH/priv-app/Lawnchair/Lawnchair.apk" 2>/dev/null || true

# 6. تزوير التوقيع الرقمي (Signature Spoofing)
echo "[*] Applying Signature Spoofing Patches (Haystack)..."
if [ ! -d "work_dir/haystack" ]; then
    git clone https://github.com/microg/Haystack.git work_dir/haystack 2>/dev/null || true
fi

if [ -d "work_dir/haystack" ] && [ -d "$SYS_PATH/framework" ]; then
    mkdir -p work_dir/framework_dir
    cp -r "$SYS_PATH/framework/"* work_dir/framework_dir/ 2>/dev/null || true
    cd work_dir/haystack
    python3 patch-files.py ../framework_dir || true
    cd ../../
    cp -r work_dir/framework_dir/* "$SYS_PATH/framework/" 2>/dev/null || true
fi

# 7. تعديل ملف build.prop وإضافة التعديلات
echo "[*] Updating build.prop with Custom Tweaks..."
BUILD_PROP=$(find work_dir/ -name "build.prop" | head -n 1)
if [ -f "$BUILD_PROP" ]; then
    cat <<EOF >> "$BUILD_PROP"

# === MicroG & Signature Spoofing Tweaks ===
ro.config.hw_fast_launch=true
persist.sys.ui.smooth=true
ro.build.signature_spoofing.enabled=true
persist.microg.support=true

# === Screen Refresh Rate & Network Tweaks ===
ro.rizo.refresh_rate=120
persist.dbg.volte_avail_ovr=1
persist.dbg.vt_avail_ovr=1
persist.dbg.wfc_avail_ovr=1
touch.pressure.scale=0.001
view.scroll_friction=0
EOF
    echo "[*] Successfully patched build.prop"
fi

# 8. تجميع الملفات النهائية المحدثة في مجلد البناء وضغطها بصيغة .tar لبرنامج Odin
echo "[*] Packaging modified files into Odin tar format..."
cp -r work_dir/* build_output/

cd build_output
tar -cvf CUSTOM_A04_MICROG_AP.tar *
cd ..

echo "=========================================================="
echo "🎉 Custom ROM Package for Odin Successfully Created! 🎉"
echo "=========================================================="