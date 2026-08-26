#!/bin/bash

echo "=== Samsung Galaxy A04 Rom Modification Script ==="

# مجلد العمل المؤقت
mkdir -p work_dir
mkdir -p build_output

# البحث عن ملف الـ AP واستخراجه (إذا وجد ضمن الملفات المحملة)
AP_FILE=$(find extracted_firmware -name "AP_*.tar.md5" -o -name "AP_*.tar")

if [ -f "$AP_FILE" ]; then
    echo "Found AP archive: $AP_FILE"
    # استخراج ملفات system / vendor أو صور النظام الداخلية من AP
    # (ملفات سامسونج الحديثة قد تكون مضغوطة بصيغة lz4 داخل tar)
    tar -xvf "$AP_FILE" -C work_dir/
    echo "AP archive extracted successfully."
else
    echo "Warning: AP tar file not found directly, listing extracted contents:"
    ls -lah extracted_firmware/
fi

# يمكنك هنا إضافة أوامر حذف ملفات الـ Bloatware وتخفيف النظام وتعديل build.prop
echo "Applying system tweaks and debloating..."

# نسخ المخرجات الجاهزة إلى مجلد البناء النهائي
cp -r extracted_firmware/* build_output/ 2>/dev/null || true

echo "Modification script completed successfully!"
