# قائمة المهام (TASKS)

## الجلسة الحالية (2026-06-17)

### مفتوحة
- [ ] تثبيت APK على الهاتف (بعد توصيل USB/ADB)
- [ ] تشغيل التطبيق واختبار عدم وجود crash
- [ ] حل أي مشاكل تظهر في logs/debug

### مكتملة
- [x] مراجعة سبب crash التطبيق (libflutter.so missing due to strip tool stub)
- [x] إصلاح NDK strip tool (llvm-strip كان exit 0 فقط)
- [x] إضافة جميع أصناف strip tools (aarch64, armv7a, x86_64, api-specific)
- [x] إنشاء أيقونة التطبيق باللون الأحمر (حرف و)
- [x] إنشاء أيقونة الإشعارات (بيضاء على شفاف)
- [x] تحديث notification service لاستخدام ic_notification
- [x] بناء APK بـ --split-per-abi (حجم 95MB arm64-v8a)
- [x] إنشاء PRD.md, PLAN.md, TASKS.md, MEMORY.md
- [x] إنشاء logs.txt و debug.txt

## الجلسات السابقة

### Session 1: الإعداد الأولي
- [x] إنشاء مشروع Flutter وتثبيت الاعتماديات
- [x] إعداد Supabase (Database, Auth, Realtime)
- [x] إعداد GetX للـ State Management
- [x] إنشاء الهيكل الأساسي للتطبيق

### Session 2: الميزات الأساسية
- [x] إضافة Auth (Login/Logout/Signup)
- [x] إضافة Orders مع تفاصيل وخريطة
- [x] إضافة QR scanner للمستخدمين
- [x] إضافة Invoices و Collection

### Session 3: التحسينات
- [x] إضافة الوضع الليلي
- [x] إضافة الإشعارات المحلية
- [x] إضافة دعم اللغات (AR/EN)
- [x] إضافة التصميم المتجاوب
- [x] تحسينات الأداء

### Session 4: البناء والتغليف
- [x] إعداد Android SDK مع stubs
- [x] حل مشاكل التوافق مع JDK 17
- [x] حل مشكلة `sqflite_android` (Java 19 APIs)
- [x] حل مشكلة `jni` و `externalNativeBuild`
- [x] تفعيل desugaring
- [x] بناء APK وتثبيته
- [x] حل مشكلة native libs (strip tool)
