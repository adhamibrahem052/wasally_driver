# قائمة المهام (TASKS)

## الجلسة الحالية (2026-06-30)

### مكتملة
- [x] مراجعة معماریة كاملة للتطبيق (Riverpod + GoRouter + Supabase)
- [x] إصلاح splash/init desync — event-driven progress بدل timer
- [x] إصلاح login routing glitch — إزالة context.go بعد signIn
- [x] إصلاح 0 EGP على البطاقات بعد إنشاء الفاتورة
- [x] إصلاح Accept Order sync — إزالة ref.refresh(driverOrdersProvider)
- [x] تغيير `driverOrdersProvider` من autoDispose → non-autoDispose
- [x] إضافة ADB telemetry (developer.log مع tag WASALLY_SYNC)
- [x] تغيير package name: `com.wasally.wasally_driver` → `com.wasally.driver`
- [x] بناء APK وتثبيت على الهاتف
- [x] إعداد ADB WiFi (192.168.11.65:5555)
- [x] تحديث AGENTS.md بقواعد Riverpod و SupabaseClient
- [x] تحديث test/order_acceptance_test.dart
- [x] رفع المشروع على GitHub (initial commit, 207 files)
- [x] تحديث MEMORY.md, TASKS.md, PRD.md
- [x] إنشاء README.md شامل

## الجلسات السابقة (2026-06-17)

### مكتملة
- [x] مراجعة سبب crash التطبيق (libflutter.so missing due to strip tool stub)
- [x] إصلاح NDK strip tool (llvm-strip كان exit 0 فقط)
- [x] إضافة جميع أصناف strip tools (aarch64, armv7a, x86_64, api-specific)
- [x] إنشاء أيقونة التطبيق باللون الأحمر (حرف و)
- [x] إنشاء أيقونة الإشعارات (بيضاء على شفاف)
- [x] تحديث notification service لاستخدام ic_notification
- [x] بناء APK بـ --split-per-abi
- [x] إنشاء PRD.md, PLAN.md, TASKS.md, MEMORY.md

### مهام سابقة
- [x] إنشاء مشروع Flutter وتثبيت الاعتماديات
- [x] إعداد Supabase (Database, Auth, Realtime)
- [x] إضافة Auth (Login/Logout/Signup)
- [x] إضافة Orders مع تفاصيل وخريطة
- [x] إضافة QR scanner
- [x] إضافة Invoices و Collection
- [x] إضافة الوضع الليلي ودعم اللغات (AR/EN)
- [x] إعداد Android SDK مع stubs وحل مشاكل JDK 17
- [x] حل مشكلة sqflite_android و jni و native libs
- [x] تفعيل desugaring وبناء APK
