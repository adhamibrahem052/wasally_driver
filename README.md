# 🚚 وصلى — Wasally Driver

تطبيق فلتر لتوصيل الطلبات مع إدارة الفواتير والتحصيل، مبني بـ Flutter + Supabase.

A Flutter-based delivery driver app for order fulfillment, invoice management, and cash collection.

---

## 📱 عن التطبيق — About

**Wasally Driver** هو تطبيق سائقين يتيح:
- استلام الطلبات وعرضها على خريطة (OpenStreetMap)
- قبول / رفض / تحديث حالة الطلبات
- مسح QR code للطلبات
- إنشاء فواتير للمتاجر
- تحصيل المدفوعات (نقدي)
- إشعارات لحظية عبر Supabase Realtime
- دعم كامل للغة العربية والإنجليزية
- واجهة Material Design 3 مع الوضع الليلي

---

## ⚙️ التقنيات — Tech Stack

| التقنية | Technology |
|---------|-----------|
| **Dart** 3.12 / **Flutter** 3.44 | Framework |
| **Riverpod 2.x** | State Management |
| **GoRouter 14.x** | Routing (redirect-based auth) |
| **Supabase** | Backend (Auth, DB, Realtime, Storage) |
| **flutter_map + latlong2** | Maps (OpenStreetMap) |
| **mobile_scanner** | QR/Barcode scanning |
| **geolocator** | Location tracking |
| **flutter_local_notifications** | Push notifications |
| **Google Fonts + Material 3** | UI/Theming |

---

## 📂 هيكل المشروع — Project Structure

```
wasally_driver/
├── lib/
│   ├── main.dart                    # Entry + boot sequence
│   ├── driver/
│   │   ├── providers/              # Riverpod providers
│   │   │   ├── auth_provider.dart   # DriverAuthNotifier
│   │   │   ├── driver_providers.dart# Streams, futures
│   │   │   └── router_provider.dart # GoRouter config
│   │   └── screens/                # All screens
│   │       ├── splash_screen.dart
│   │       ├── login_screen.dart
│   │       ├── dashboard_screen.dart
│   │       ├── order_detail_screen.dart
│   │       ├── invoice_screen.dart
│   │       └── ... (10+ screens)
│   └── shared/
│       ├── localization/           # AR/EN (374 keys)
│       ├── models/                 # Data models
│       ├── providers/              # Shared providers
│       ├── services/               # Supabase services
│       ├── theme/                  # Light/Dark themes
│       └── widgets/                # Common widgets
├── test/
│   └── order_acceptance_test.dart  # Stream continuity tests
├── docs/
│   ├── AGENTS.md                   # AI coding rules
│   ├── MEMORY.md                   # Project memory/context
│   ├── PRD.md                      # Product requirements
│   ├── TASKS.md                    # Task tracking
│   └── superpowers/specs/          # Technical reports
└── android/
    └── app/src/main/kotlin/com/wasally/driver/
        └── MainActivity.kt        # Package: com.wasally.driver
```

---

## 🚀 بناء وتشغيل — Build & Run

### المتطلبات — Prerequisites
- Flutter 3.44 (Dart 3.12)
- JDK 17
- Android SDK 36 (with stubs for API 36)
- Gradle 9.1.0 + AGP 9.0.1

### Build
```bash
flutter build apk --debug --split-per-abi
```

### Install via ADB
```bash
adb connect 192.168.11.65:5555
adb install build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk
```

### Run directly
```bash
flutter run --debug
```

---

## 📊 قاعدة البيانات — Database (Supabase)

- `profiles` — Driver profiles
- `orders` — Orders (real-time synced)
- `invoices` + `invoice_items` — Store invoices
- `stores` — Store records
- `collections` — Cash collection records
- `notifications` — Push notifications
- `driver_locations` — Live location tracking
- `complaints` / `messages` — Shared chat (also used by Customer App)
- `driver_store_invoices` — Store invoice summaries

> ⚠️ **Shared tables**: `orders`, `notifications`, `complaints`, `messages` are shared with the Customer App — changes affect both apps.

---

## 🧠 State Management Rules

| Rule | Description |
|------|------------|
| `StreamProvider` ≠ `autoDispose` | Realtime streams must not auto-dispose |
| No `invalidate()` on streams | Let realtime subscriptions deliver updates |
| `supabaseClientProvider` | Use instead of `Supabase.instance.client` |
| GoRouter redirect | Controls all navigation — no `context.go()` after auth |

---

## 📡 ADB Telemetry

Built-in logging with `WASALLY_SYNC` tag:
```bash
adb logcat -s WASALLY_SYNC
```

Tracks auth state, order stream emissions, accept-order lifecycle, and performance.

---

## 🔗 روابط — Links

- **GitHub**: https://github.com/adhamibrahem052/wasally_driver
- **Supabase Console**: https://supabase.com/dashboard/project/oyrexsyebgplfretcvko
- **Device**: Huawei JKM-LX1 (Android 9, arm64-v8a)
- **Internet**: ~200 KB/s connection

---

## 📄 الترخيص — License

All rights reserved — Wasally Driver
