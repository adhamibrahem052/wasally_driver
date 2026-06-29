# تعليمات للـ AI Agent

## قبل البدء بأي مهمة
1. اقرأ MEMORY.md أولاً لفهم السياق
2. اقرأ PLAN.md لمعرفة المرحلة الحالية
3. اقرأ TASKS.md لمعرفة المهام المنجزة والمفتوحة

## البيئة
- **OS**: Linux Mint 22.3
- **Shell**: bash
- **JAVA_HOME**: `/usr/lib/jvm/java-17-openjdk-amd64`
- **ANDROID_HOME**: `~/Android/Sdk`
- **Flutter**: `/home/mazikaa/Desktop/wasally_user/flutter`
- **مسار المشروع**: `/home/mazikaa/Desktop/wasally_user/wasally_driver`

## الأوامر الأساسية
```
flutter build apk --debug --split-per-abi
flutter run --debug
adb connect 192.168.11.67:5555
adb logcat -s flutter:* AndroidRuntime:* "*:F"
```

## ملاحظات مهمة
- دائماً أضبط JAVA_HOME و ANDROID_HOME قبل تشغيل flutter أو gradle
- `android.ndk.suppressMinSdkVersionError=34` في gradle.properties
- لا تحاول تحديث الـ Gradle wrapper أو تغيير إصدار AGP
- لا تحاول تحميل NDK كامل أو SDK packages
