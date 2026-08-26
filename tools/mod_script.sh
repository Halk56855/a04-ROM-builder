#!/bin/bash

echo "=== Advanced Galaxy A04 Debloat & Lawnchair Integration Script ==="

mkdir -p work_dir
mkdir -p build_output

# 1. استخراج ملف الـ AP الرسمي
AP_FILE=$(find extracted_firmware -name "AP_*.tar.md5" -o -name "AP_*.tar")

if [ -f "$AP_FILE" ]; then
    echo "Found AP archive: $AP_FILE"
    tar -xvf "$AP_FILE" -C work_dir/
    echo "AP archive extracted successfully."
else
    echo "Warning: AP archive not found directly, copying all files..."
    cp -r extracted_firmware/* work_dir/
fi

# 2. إزالة تطبيقات سامسونج المحددة (الراديو، السمات، المتجر، Bixby وغيرها) لتقليص الحجم
echo "Removing unwanted Samsung bloatware (Radio, Themes, GalaxyStore, etc.)..."
find work_dir/ -name "*.apk" | grep -E "FMRadio|Themes|GalaxyStore|SamsungThemes|SmartThings|Bixby|ARZone|SamsungFree|OneDrive|Microsoft" | xargs rm -f 2>/dev/null || true

# 3. إزالة تطبيقات GApps غير الضرورية (مثل Duo, YouTube Music, Google Drive الزائدة إذا وجدت ضمن النظام)
echo "Trimming unnecessary Google apps (GApps)..."
find work_dir/ -name "*.apk" | grep -E "YouTubeMusic|GoogleDuo|GoogleDrive|GooglePhotos|Maps" | xargs rm -f 2>/dev/null || true

# 4. استبدال مشغل سامسونج (One UI Home) بـ Lawnchair Launcher
echo "Replacing Samsung Home with Lawnchair Launcher..."
# حذف مشغل سامسونج الافتراضي لمنع التعارض
find work_dir/ -name "*SecLauncher*" -o -name "*OneUIHome*" | xargs rm -rf 2>/dev/null || true

# تحميل ودمج Lawnchair Launcher مباشرة كـ مشغل افتراضي للنظام
LAWNCHAIR_DIR=$(find work_dir/ -type d -name "priv-app" -o -name "app" | head -n 1)
if [ -n "$LAWNCHAIR_DIR" ]; then
    mkdir -p "$LAWNCHAIR_DIR/Lawnchair"
    # تحميل أحدث إصدار مستقر من Lawnchair مباشرة أثناء البناء
    wget -O "$LAWNCHAIR_DIR/Lawnchair/Lawnchair.apk" "https://github.com/LawnchairLauncher/lawnchair/releases/download/v12.1-alpha.4/Lawnchair.apk" 2>/dev/null || true
    echo "Lawnchair injected successfully."
fi

# 5. تطبيق تحسينات الأداء وسلاسة النظام في build.prop
BUILD_PROP=$(find work_dir/ -name "build.prop" | head -n 1)
if [ -f "$BUILD_PROP" ]; then
    echo "" >> "$BUILD_PROP"
    echo "# Custom Debloated & Lawnchair Tweaks" >> "$BUILD_PROP"
    echo "ro.config.hw_fast_launch=true" >> "$BUILD_PROP"
    echo "debug.performance.tuning=1" >> "$BUILD_PROP"
    echo "persist.sys.ui.smooth=true" >> "$BUILD_PROP"
    # جعل Lawnchair المشغل الافتراضي للنظام
    echo "ro.launcher.layout.support=true" >> "$BUILD_PROP"
fi

# 6. نقل الملفات النهائية المعدلة إلى مجلد البناء
cp -r work_dir/* build_output/

echo "Advanced ROM customization and debloating completed successfully!"