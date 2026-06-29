# ملف الذاكرة (Memory/Context)

## معلومات المشروع
- **اسم المشروع**: wasally_driver (تطبيق وصلى)
- **المسار**: `/home/mazikaa/Desktop/wasally_user/wasally_driver`
- **Flutter SDK**: `/home/mazikaa/Desktop/wasally_user/flutter` (3.44.0 stable)
- **JAVA_HOME**: `/usr/lib/jvm/java-17-openjdk-amd64` (JDK 17)
- **ANDROID_HOME**: `~/Android/Sdk`

## الهاتف
- **الجهاز**: Huawei JKM-LX1 (P Smart 2019)
- **Android**: 9 API 28
- **المعمارية**: arm64-v8a
- **الشبكة**: 192.168.11.67 (WiFi)
- **ADB**: لاسلكي على port 5555

## إعدادات SDK الخاصة

### NDK Stub
- **المسار**: `~/Android/Sdk/ndk/28.2.13676358/`
- **ملف ABIs**: `meta/abis.json` (arm64-v8a, armeabi-v7a, x86_64, x86)
- **المترجمات**: `toolchains/llvm/prebuilt/linux-x86_64/bin/`
  - clang/clang++ wrappers تستخدم system clang مع `--target=`
  - llvm-strip يستخدم `/usr/bin/llvm-strip-18` (تم الإصلاح!)
  - جميع strip targets (aarch64, armv7a, x86_64 + api-specific)

### Platform 36 Stub
- **المسار**: `~/Android/Sdk/platforms/android-36/`
- **مبني على**: platform 34 مع إضافة `VERSION_CODES.BAKLAVA = 36`
- **source.properties**: ApiLevel=36

### Build-Tools 36
- **المسار**: `~/Android/Sdk/build-tools/36.0.0/`
- **نسخة من**: build-tools 34.0.0 مع source.properties معدل

### CMake Stub
- **المسار**: `~/Android/Sdk/cmake/3.22.1/bin/cmake`
- **يشاور على**: `/usr/bin/cmake`

## Gradle Configuration
- **AGP**: 9.0.1
- **Kotlin**: 2.3.20
- **Gradle**: 9.1.0
- **compileSdk**: 36
- **minSdk**: 24 (flutter.minSdkVersion)
- **targetSdk**: 36 (flutter.targetSdkVersion)
- **desugaring**: مفعل (`isCoreLibraryDesugaringEnabled = true`)
- **timeouts**: socket 300s, connection 120s

## الحزم المعدلة (pub cache)
- `jni-1.0.0/android/build.gradle`: externalNativeBuild معطل
- `sqflite_android-2.4.3/Utils.java`: `Locale.of` ← `new Locale`, `thread.threadId()` ← `thread.getId()`
- `path_provider_android-2.3.1` → 2.3.0 (تجنب مشكلة jni)

## APK
- **آخر بناء**: app-arm64-v8a-debug.apk (95MB)
- **المسار**: `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`
- **الـ native libs**: مضمنة (بعد إصلاح llvm-strip)
- **الأيقونة**: حمراء بحرف "و" أبيض
- **أيقونة الإشعارات**: بيضاء على شفاف

## Crash History
1. ~~Could not find 'libflutter.so'~~ ✅ (تم الإصلاح - strip tool كان exit 0)
2. ~~MissingLibraryException for libflutter.so~~ ✅

## كلمات المرور
- **تطبيق**: wasallydriver149
- **Supabase anon key**: eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9zdGZ3dHF3bm55ZnBhcXp4aG1qIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDY3OTM1ODcsImV4cCI6MjA2MjM2OTU4N30.VAkZJZ3ydwDgpFGK7y9ldCckGQaE5qVxzRFQP8H8OeY
- **Supabase URL**: https://ostfwtqwnnyfpaqzxhmj.supabase.co

## الأوامر المهمة
```bash
# بناء APK (split per ABI)
flutter build apk --debug --split-per-abi

# ADB
adb connect 192.168.11.67:5555
adb install app-arm64-v8a-debug.apk
adb logcat -s flutter:* AndroidRuntime:* "*:F"

# Gradle مباشر
cd android && ./gradlew :app:packageDebug

# تشغيل مباشر
flutter run --debug
```

## ملاحظات
- اتصال الإنترنت بطيء جداً (~200 KB/s) - نتجنب تحميل حزم كبيرة
- Java 21 JRE مثبت لكن JDK 17 يستخدم للبناء
- flutter build يتجاهل JAVA_HOME أحياناً - نضبط المتغيرات قبل كل build
