# وثيقة متطلبات المنتج - تطبيق وصلى (Wasally Driver)

## 1. نظرة عامة
تطبيق فلتر لتوصيل الطلبات مع فواتير للمتاجر، يستخدم Supabase كقاعدة بيانات خلفية،
مع ماسح باركود QR ومزامنة لحظية.

## 2. الميزات الأساسية

### 2.1 المصادقة
- تسجيل دخول/خروج باستخدام Supabase Auth (email/password)
- حماية المسارات بناءً على حالة تسجيل الدخول
- تخزين حالة الجلسة محلياً

### 2.2 إدارة الطلبات
- عرض قائمة الطلبات (جاري، مكتمل، ملغي)
- تفاصيل الطلب مع خريطة
- تغيير حالة الطلب (قبول، رفض، توصيل، تسليم)
- بحث وتصفية الطلبات
- QR code لكل طلب

### 2.3 الفواتير
- إنشاء فاتورة لمتجر
- طباعة الفاتورة (PDF)
- عرض سجل الفواتير
- حالة الدفع (مدفوع/غير مدفوع)

### 2.4 التحصيل
- تسجيل تحصيل نقدي
- متابعة المبيعات اليومية
- إجمالي المبيعات والتحصيلات

### 2.5 الإشعارات
- إشعارات الطلبات الجديدة عبر Realtime Supabase
- إشعارات محلية (flutter_local_notifications)
- إصدار صوت عند طلب جديد

### 2.6 الخريطة والملاحة
- عرض موقع العميل على خريطة OpenStreetMap
- فتح المسار في تطبيق خرائط خارجي
- تحديث موقع السائق في الخلفية (geolocator)

### 2.7 ماسح الباركود
- مسح QR code للطلبات باستخدام mobile_scanner
- معالجة الباركود وعرض معلومات الطلب

### 2.8 الإعدادات
- الوضع الليلي
- تغيير اللغة (AR/EN)
- إعدادات الإشعارات
- معلومات الحساب

### 2.9 المزامنة
- مزامنة الطلبات مع Supabase في الخلفية
- استخدام Supabase Realtime للتحديثات اللحظية
- تخزين مؤقت (cache) للبيانات

## 3. المعمارية

### 3.1 التقنيات
- Flutter 3.44 (Dart SDK)
- Supabase (Database, Auth, Realtime, Storage)
- GetX (State Management, Routing)
- flutter_map (OpenStreetMap)
- mobile_scanner (QR/Barcode)
- flutter_local_notifications
- geolocator
- sqflite (local cache)
- connectivity_plus
- app_links (deep links)

### 3.2 بنية المجلدات
```
lib/
  app/               # تكوين التطبيق (السمات، التوجيه، الربط)
  core/              # الأساسيات (الألوان، الثوابت، الأدوات، الشبكة)
  features/          # الميزات (auth, orders, invoices, collection)
  shared/            # مشترك (الخدمات، القطعة المشتركة)
```

### 3.3 حالة التطبيق
- GetX Controllers لكل feature
- Service classes للتواصل مع Supabase
- Repositories للبيانات المحلية

## 4. الصفحات

### 4.1 Auth (بدون تسجيل دخول)
- `/login` - تسجيل الدخول
- `/forgot-password` - استعادة كلمة المرور

### 4.2 رئيسية (تتطلب تسجيل دخول)
- `/home` - الشاشة الرئيسية مع قائمة الطلبات
- `/orders` - تفاصيل الطلبات
- `/order/:id` - تفاصيل طلب معين
- `/invoice/new` - إنشاء فاتورة جديدة
- `/invoices` - قائمة الفواتير
- `/collection` - صفحة التحصيل
- `/settings` - الإعدادات
- `/profile` - الملف الشخصي

## 5. قاعدة البيانات (Supabase)

### 5.1 الجداول
- `profiles` - بيانات السائقين
- `orders` - الطلبات
- `invoices` - الفواتير
- `collections` - التحصيلات
- `stores` - المتاجر
- `notifications` - الإشعارات

### 5.2 سياسات الأمان (RLS)
- كل سائق يرى فقط بياناته
- المشرف يمكنه رؤية كل شيء
- تم تنفيذ `supabase_rls_policies.sql`

## 6. البيئة

### 6.1 الأجهزة
- هاتف: Huawei JKM-LX1 (P Smart 2019)
- Android 9 API 28, arm64-v8a
- اللابتوب: Linux Mint 22.3
- اتصال إنترنت بطيء (~200 KB/s)

### 6.2 SDK والمكتبات
- compileSdk = 36 (platform stub)
- minSdk = 24, targetSdk = 36
- AGP 9.0.1
- Kotlin 2.3.20
- Gradle 9.1.0
- Flutter SDK at `/home/mazikaa/Desktop/wasally_user/flutter`
- NDK stub في `~/Android/Sdk/ndk/28.2.13676358/`
- Platform 36 stub (مبني على platform 34 مع إضافة BAKLAVA)
- build-tools 36.0.0 (نسخة من build-tools 34.0.0)
- JDK 17 (`JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`)

### 6.3 المتغيرات البيئية
```
JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
ANDROID_HOME=~/Android/Sdk
ANDROID_SDK_ROOT=~/Android/Sdk
```
