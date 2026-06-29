# Wasally Driver — Technical Architecture Report

**Date:** 2026-06-27
**Version:** 3.0
**Package:** `com.wasally.wasally_driver`
**Supabase Project:** `oyrexsyebgplfretcvko`

---

## 1. Project Overview

Wasally Driver is a Flutter-based delivery driver application that manages order fulfillment, invoice generation, and cash collection for retail stores. It uses Supabase as its backend (auth, database, realtime, storage) and targets Android 9+ (API 28) devices, specifically the Huawei P Smart 2019 (JKM-LX1, arm64-v8a).

The app is bilingual (Arabic/English) with localization managed through a custom `AppLocalizations` class (374 translation keys). The UI is Material Design 3 with both light and dark themes — themes defined in `shared/theme/app_theme.dart` and exposed via `themeProvider` in `shared/providers/theme_provider.dart`.

---

## 2. State Management: Riverpod 2.x

The app uses Riverpod 2.x (via `flutter_riverpod`) for state management. The following provider types are used:

### 2.1 Provider Types in Use

| Type | Purpose | Examples |
|------|---------|---------|
| `StreamProvider` | Realtime data streams | `driverOrdersProvider`, `driverNotificationsProvider` |
| `FutureProvider` / `FutureProvider.family` | Single-shot data with params | `driverProfileProvider`, `driverCollectionsProvider` |
| `StateNotifierProvider` | Mutable auth state with methods | `driverAuthProvider` |
| `Provider` | Derived/sync state / service singletons | `supabaseClientProvider`, `driverNotifServiceProvider` |

### 2.4 Key Pattern: Never Invalidate/Refresh StreamProviders

A critical architectural rule discovered during debugging: **StreamProviders backed by Supabase realtime subscriptions should never be `invalidate()`d or `refresh()`ed from screens.** Doing so kills and recreates the underlying subscription, creating a race condition window where:

1. The old subscription is cancelled
2. The new subscription fires before the DB write is committed
3. The consumer reads stale data (e.g., `final_total = 0`)

**Instead:** Let the realtime subscription deliver updates automatically when the DB changes. Screens that need to react to DB mutations should use screen-local providers (e.g., `_invoiceProvider`) or Supabase realtime streams (e.g., `_invoiceRealtimeSub` in `OrderDetailScreen`).

### 2.2 Provider Architecture (Post-Stabilization)

```
                    ┌──────────────────────────────────┐
                    │      supabaseClientProvider       │
                    │  (Provider<SupabaseClient>)        │
                    │  - Single source of SupabaseClient │
                    │  - Injected into all services      │
                    └──────────┬───────────────────────┘
                               │
              ┌────────────────┼────────────────────┐
              │                │                     │
              ▼                ▼                     ▼
  ┌────────────────────┐ ┌──────────────────┐ ┌──────────────────┐
  │  DriverAuthNotifier │ │ DriverProviders   │ │ Screen-local     │
  │  (StateNotifier)    │ │ (Stream/Future)   │ │ Providers        │
  │  - signIn/signUp/   │ │ - orders          │ │ - _walletService │
  │    signOut          │ │ - notifications   │ │ - _chatService   │
  │  - injected client  │ │ - profile         │ │ - _collections   │
  └──────────┬─────────┘ │ - collections     │ │ - _qrService     │
             │           │ - stores           │ │ etc.             │
             │           └────────┬──────────┘ └──────────────────┘
             │                    │
             │                    ▼
             │           ┌──────────────────┐
             │           │  Service Layer   │
             └──────────►│  (Constructors)  │
                         │  - OrderService  │
                         │  - InvoiceService│
                         │  - StoreService  │
                         │  - PaymentService│
                         │  - ...           │
                         └──────────────────┘
```

**Key change from v1.0:** `SupabaseClient` is no longer fetched via `Supabase.instance.client` singletons inside each service. Instead, `supabaseClientProvider` is the single source of truth, and every service class accepts `SupabaseClient` via its constructor. All provider definitions use `ref.read(supabaseClientProvider)`.

### 2.3 Provider Files

| File | Providers |
|------|-----------|
| `lib/shared/providers/supabase_client_provider.dart` | `supabaseClientProvider` — single `SupabaseClient` source |
| `lib/driver/providers/auth_provider.dart` | `driverAuthProvider` — auth state notifier (accepts client via constructor) |
| `lib/driver/providers/driver_providers.dart` | ~12 providers (orders, notifications, profile, collections, stores) — `driverOrdersProvider` uses `StreamProvider` (non-autoDispose) |
| `lib/driver/providers/router_provider.dart` | `driverRouterProvider` — GoRouter with auth redirect |
| `lib/shared/providers/theme_provider.dart` | `themeProvider` — dark/light mode |
| `lib/shared/providers/locale_provider.dart` | `localeProvider` — ar/en switching |
| `lib/shared/providers/connectivity_provider.dart` | `connectivityProvider` — network state |
| `lib/shared/providers/logger_provider.dart` | `logService` provider |

---

## 3. Routing: GoRouter ^14.8.1

### 3.1 Route Structure (Actual)

Route paths are centralized in `RoutePaths` constants (`lib/shared/constants/route_paths.dart`). All screen files import and use the constants instead of hardcoded strings.

```
/ ──────────────────► redirect to /splash (or /login if unauthenticated)
├── /splash              DriverSplashScreen
├── /login               DriverLoginScreen
├── /register            DriverRegisterScreen
├── /dashboard           DriverDashboardScreen (ShellRoute parent)
│   ├── orders           DriverOrdersScreen
│   ├── order-detail/:id DriverOrderDetailScreen
│   ├── notifications    DriverNotificationsScreen
│   ├── collections      DriverCollectionsScreen
│   ├── invoice/:orderId/:customerId  DriverInvoiceScreen
│   ├── chat/:orderId/:customerId     DriverChatScreen
│   ├── qr-code/:orderId DriverQrCodeScreen
│   ├── profile          DriverProfileScreen
│   ├── edit-profile     DriverEditProfileScreen
│   ├── settings         DriverSettingsScreen
│   ├── about            DriverAboutScreen
│   ├── terms            DriverTermsScreen
│   ├── store-invoices   DriverStoreInvoicesScreen
│   └── logs             LogViewerScreen
```

### 3.2 Auth Guard

The `routerProvider` uses GoRouter's redirect to check `DriverAuthState`:
- Unauthenticated on any non-auth route → redirect to `/login`
- Authenticated on `/login`, `/register`, or `/splash` → redirect to `/dashboard`
- Auth routes determined by checking against `RoutePaths.login`, `RoutePaths.register`, `RoutePaths.splash`

### 3.3 Route Constants Pattern

```dart
// lib/shared/constants/route_paths.dart
class RoutePaths {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String dashboard = '/dashboard';
  static const String dashboardOrders = '/dashboard/orders';
  static String dashboardOrderDetail(String id) => '/dashboard/order-detail/$id';
  static String dashboardInvoice(String orderId, String customerId) => '/dashboard/invoice/$orderId/$customerId';
  static String dashboardChat(String orderId, String customerId) => '/dashboard/chat/$orderId/$customerId';
  static String dashboardQrCode(String orderId) => '/dashboard/qr-code/$orderId';
  // ... plus all other routes
}
```

---

## 4. Database Schema

### 4.1 Tables (21 total)

| Table | Primary Purpose | Key Columns |
|-------|----------------|-------------|
| `stores` | Store entities | `id, name, address, phone` |
| `orders` | Customer orders | `id, store_id, driver_id, status, items, subtotal, delivery_fee, final_total` |
| `invoices` | Store invoices | `id, store_id, driver_id, total_amount, status, payment_status` |
| `invoice_items` | Invoice line items | `id, invoice_id, product_name, quantity, unit_price` |
| `delivery_locations` | Customer delivery addresses | `id, order_id, latitude, longitude` |
| `profiles` | Driver profiles | `id (UUID), full_name, phone, avatar_url` |
| `daily_collections` | Daily cash collection | `id, driver_id, store_id, total_collected` |
| `collection_invoices` | Collection-invoice link | `id, collection_id, invoice_id` |
| `notifications` | Push notifications | `id, user_id, title, body, type, reference_id, is_read` |
| `messages` | Driver-customer chat | `id, sender_id, receiver_id, order_id, message, is_read` |
| `complaints` | User complaints | `id, user_id, type, title, description, status, admin_reply` |
| `ratings` | Order ratings | `id, order_id, user_id, driver_rating, app_rating, comment` |
| `payments` | Payment records | `id, user_id, order_id, amount, payment_method, status` |
| `payment_methods` | Available payment methods | `id, type, name, details, is_active` |
| `wallet_transactions` | Wallet history | `id, user_id, type, amount, balance_before, balance_after` |
| `driver_locations` | Real-time driver GPS | `id, driver_id, latitude, longitude, updated_at` |
| `driver_store_invoices` | Driver-store invoice records | `id, driver_id, store_id, total_amount, status` |

### 4.2 Key Relationships

```
stores 1──N orders
stores 1──N invoices
orders 1──1 delivery_locations
invoices 1──N invoice_items
drivers 1──N orders (assigned)
drivers 1──N invoices (created)
drivers 1──N daily_collections
daily_collections N──M invoices (via collection_invoices)
```

### 4.3 Indexes

Tables have indexes on: `driver_id`, `store_id`, `status`, `created_at`, and `(driver_id, status)` for the most common query patterns.

### 4.4 RLS Policies

Row-Level Security ensures each driver can only:
- Read/write their own orders (`driver_id = auth.uid()`)
- Read/write their own invoices
- Read/write their own collections
- Read store data referenced by their orders/invoices
- Read/write their own profile

Admin bypass is via `is_admin()` function check.

---

## 5. Service Layer

### 5.1 Service Files

| File | Key Methods | SupabaseClient Source |
|------|-------------|----------------------|
| `lib/shared/services/order_service.dart` | `streamDriverOrders()`, `acceptOrder()`, `updateOrderStatus()`, `deleteOrder()`, `getOrderById()` | Constructor injection |
| `lib/shared/services/invoice_service.dart` | `createInvoice()`, `updateInvoice()`, `deleteInvoice()`, `getInvoiceWithItems()`, `getInvoiceStream()` | Constructor injection |
| `lib/shared/services/store_service.dart` | `getStores()`, `getStore()`, `createStore()`, `searchStores()` | Constructor injection |
| `lib/shared/services/collection_service.dart` | `getDriverCollections()`, `getRemainingForDriver()`, `getDriverCollectionsStream()` | Constructor injection |
| `lib/shared/services/notification_service.dart` | `getNotificationsStream()`, `markAsRead()`, `markAllAsRead()`, `getUnreadCount()` | Constructor injection |
| `lib/shared/services/message_service.dart` | `getMessages()`, `getMessagesStream()`, `sendMessage()`, `getUnreadCount()` | Constructor injection |
| `lib/shared/services/complaint_service.dart` | `submitComplaint()`, `getUserComplaints()`, `getComplaintsStream()`, `getAdminId()` | Constructor injection |
| `lib/shared/services/rating_service.dart` | `submitRating()` | Constructor injection |
| `lib/shared/services/payment_service.dart` | `processPayment()`, `getPaymentMethods()`, `getWalletTransactions()`, `getWalletBalance()`, `deductWallet()`, balance streams | Constructor injection |
| `lib/shared/services/location_service.dart` | `getDriverLocationStream()` | Constructor injection |
| `lib/shared/services/logger_service.dart` | `logService` singleton (no Supabase dependency) | N/A |

### 5.2 Service Implementation Pattern (Post-Stabilization)

All services now follow a consistent pattern:

1. **Constructor injection of `SupabaseClient`** — no more `Supabase.instance.client` singletons
2. **Private `_supabase` field** — stores the injected client for all queries
3. **Supabase Dart query builder** — uses the Supabase Flutter SDK
4. **Manual `fromMap()`/`toMap()`** — serialization in model classes remains unchanged
5. **No repository abstraction layer** — screens call services through Riverpod providers

**Before (global singleton):**
```dart
class OrderService {
  final SupabaseClient _supabase = Supabase.instance.client;
  Future<void> doSomething() => _supabase.from('table').select();
}
```

**After (constructor injection):**
```dart
class OrderService {
  final SupabaseClient _supabase;
  OrderService(this._supabase);
  Future<void> doSomething() => _supabase.from('table').select();
}
```

### 5.3 Service Provider Injection Pattern

All services are instantiated through Riverpod providers that inject `supabaseClientProvider`:

```dart
// In provider files:
final driverOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) {
  final service = OrderService(ref.read(supabaseClientProvider));
  return service.getDriverOrdersStream(user.id);
});
```

This pattern ensures:
- Single `SupabaseClient` instance across the app
- Easy testing — mock `SupabaseClient` can be injected via override
- No global state — all dependencies are explicit

### 5.4 What Changed: `other_services.dart` Split

The monolithic `lib/shared/services/other_services.dart` contained 6 service classes sharing a file:
- `NotificationService`
- `MessageService`
- `ComplaintService`
- `RatingService`
- `PaymentService`
- `LocationService`

Each is now in its own file with clean imports and constructor injection. The old file was deleted after verifying zero remaining imports.

---

## 6. Model Layer

### 6.1 Model Files

| File | Key Fields |
|------|-----------|
| `order_model.dart` | `id, storeId, driverId, status, items, subtotal, deliveryFee, finalTotal, createdAt` |
| `invoice_model.dart` | `id, storeId, driverId, items (List<InvoiceItem>), totalAmount, status, paymentStatus` |
| `store_models.dart` | `StoreModel, DriverCollection, DriverStoreInvoice` |
| `user_model.dart` | `id, fullName, phone, avatarUrl, role, walletBalance` |
| `other_models.dart` | `NotificationModel, MessageModel, ComplaintModel, RatingModel, PaymentMethod, WalletTransaction, PaymentModel, LocationModel` |

All models use `fromMap()` factory constructors and `toMap()` methods for Supabase JSON serialization. `OrderModel.fromMap` handles both `Map<String, dynamic>` and nested JSON string parsing for `items`.

---

## 7. Screen Analysis

### 7.1 Screen Inventory (20 screens, actual)

| Screen | File | State Source | Key Actions |
|--------|------|-------------|-------------|
| SplashScreen | `splash_screen.dart` | — | pass-through route — GoRouter redirect handles all navigation |
| LoginScreen | `login_screen.dart` | `driverAuthProvider` | signIn, navigate to register |
| RegisterScreen | `register_screen.dart` | `driverAuthProvider` | signUp, navigate to login |
| DashboardScreen | `dashboard_screen.dart` | `driverOrdersProvider` | summary cards, order list, nav |
| OrdersScreen | `orders_screen.dart` | `driverOrdersProvider` | view all orders, navigate to detail |
| OrderDetailScreen | `order_detail_screen.dart` | providers + Supabase | accept/reject, deliver, navigate |
| InvoiceScreen | `invoice_screen.dart` | services + providers | create/edit invoice, add items, save |
| ChatScreen | `chat_screen.dart` | `_chatServiceProvider` | send/receive messages |
| QrCodeScreen | `qr_code_screen.dart` | providers | display QR code for order |
| ScanQrScreen | `scan_qr_screen.dart` | `_scanServiceProvider` | scan QR → navigate to order |
| NotificationsScreen | `notifications_screen.dart` | `driverNotifServiceProvider` | view/clear notifications |
| CollectionsScreen | `collections_screen.dart` | `_collectionsServiceProvider` | view daily collections |
| WalletScreen | `wallet_screen.dart` | `_walletServiceProvider` | view balance, transactions |
| StoreInvoicesScreen | `store_invoices_screen.dart` | Supabase direct | view store invoices |
| ProfileScreen | `profile_screen.dart` | `driverAuthProvider` | view profile, logout |
| EditProfileScreen | `edit_profile_screen.dart` | Supabase direct | edit name, phone, avatar |
| SettingsScreen | `settings_screen.dart` | `themeProvider` | theme, lang, about, logs |
| AboutScreen | `about_screen.dart` | — | version info |
| TermsScreen | `terms_screen.dart` | — | terms and conditions |
| LogViewerScreen | `log_viewer_screen.dart` | — | view app logs |

### 7.2 Critical Screens

**InvoiceScreen** (`lib/driver/screens/invoice_screen.dart`, ~873 lines):
- Complex screen handling both create and edit modes
- Container for invoice form, customer info, store info, items list, totals, realtime subscription
- Uses injected `InvoiceService` and `OrderService` via providers
- Key methods: `_saveInvoice()`, `_updateInvoice()`, `_loadInvoice()`, `_populateFromInvoice()`
- **Bug fixed (v1):** In `_saveInvoice()`, the `orders.final_total` DB update was done AFTER the provider refresh, causing zero total display. Fixed by reordering: DB update first, then providers refresh.
- **Bug fixed (v2):** `ref.invalidate()` calls on shared StreamProviders (`driverOrdersProvider`, `detailOrderProvider`, `detailInvoiceProvider`) were removed. Supabase realtime subscriptions deliver DB updates automatically — invalidating kills the subscription and creates a race condition. Only screen-local providers (`_invoiceProvider`, `_invoiceOrderProvider`) are invalidated.

**OrderDetailScreen** (`lib/driver/screens/order_detail_screen.dart`, ~568 lines):
- Shows full order details with map, items list, and action buttons
- `_acceptOrder()`: updates status, sets driver_id, refreshes providers
- Accept button visibility: checks `order.driverId == null` AND `order.status == "pending"`
- Uses injected `OrderService` and `InvoiceService` via providers
- **Bug fixed (v2):** All `ref.refresh(driverOrdersProvider)` calls removed from `_acceptOrder()`, `_updateStatus()`, and invoice button callbacks. Using screen-local realtime subscriptions (`_orderRealtimeSub`, `_invoiceRealtimeSub`) for cross-screen sync instead.

---

## 8. Data Flow Analysis

### 8.1 Authentication Flow

The auth provider (`DriverAuthNotifier`) subscribes to Supabase `onAuthStateChange` events to reactively update state whenever the session changes (login, logout, token refresh):

```
App start → DriverAuthNotifier constructor
                  │
                  ├── Check existing session
                  ├── Subscribe to onAuthStateChange
                  │     └── Listener updates state when auth events fire
                  │         (preserves isLoading flag during active signIn)
                  └── Expose state via ref.watch(driverAuthProvider)

User log in → LoginScreen → driverAuthProvider.signIn(email, password)
                                 │
                                 ▼
                           _supabase.auth.signInWithPassword()
                                 │
                                 ├── onAuthStateChange fires SIGNED_IN
                                 │     └── Listener skips update (isLoading=true)
                                 ├── Get profile from profiles table
                                 ├── Verify role == 'driver'
                                 └── Update state (isLoading=false) → UI rebuilds via ref.watch
                                     → GoRouter redirect detects authenticated → /dashboard

Note: GoRouter redirect handles all auth routing. Screens do NOT call
context.go() after auth actions — the redirect in router_provider.dart
reacts to state changes automatically.
```

### 8.2 Boot Initialization Flow (Event-Driven Splash)

The boot sequence in `main.dart` transitions from a timer-based splash to an event-driven one:

```
App launch → main() runApp()
                  │
                  ├── Display _SplashApp (AnimatedSwitcher, no GoRouter yet)
                  │     └── Progress bar driven by _setProgress() calls
                  │
                  └── _SplashState.initState() → initialize()
                        │
                        ├── 0.10 Init SharedPreferences
                        ├── 0.30 Init logger service
                        ├── 0.40 Init Supabase.instance
                        ├── 0.50 Init firebase messaging / notifications
                        ├── 0.70 SharedPreferences loaded
                        ├── 0.85 Check currentSession
                        ├── 0.95 Settle delay
                        └── 1.00 Build GoRouter → AnimatedSwitcher swaps to MaterialApp
                              └── Splash screen renders → GoRouter immediately redirects
                                  based on auth state (/dashboard or /login)
```

### 8.3 Service Data Flow Pattern

```
User Action → Screen → Provider (ref.read)
                 │
                 ▼
           Service (constructed with injected SupabaseClient)
                 │
                 ├── _supabase.from('table').select/insert/update
                 ├── Await response
                 └── Return typed model
                 │
                 ▼
           Provider refreshes (invalidate/stream)
                 │
                 ▼
           Consumer rebuilds (when()/StreamBuilder)
```

### 8.4 Invoice Creation Flow (Bug Fix Documentation)

**Before fix:** `orders.final_total` update was AFTER provider refresh — consumers read stale 0.

```
_saveInvoice()
  ├── Upsert invoice + items
  ├── Refresh driverOrdersProvider   ◄── BUG: reads final_total=0
  ├── Update orders.final_total      ◄── Too late
  └── Refresh invoice providers
```

**After fix:** DB update happens BEFORE provider refresh.

```
_saveInvoice()
  ├── Upsert invoice + items
  ├── Update orders.final_total      ◄── NOW first
  ├── Refresh driverOrdersProvider   ◄── Reads correct total
  └── Refresh invoice providers
```

---

## 9. Build Environment

### 9.1 Development Machine

| Component | Value |
|-----------|-------|
| OS | Linux Mint 22.3 |
| Flutter | `/home/mazikaa/Desktop/wasally_user/flutter` (custom path) |
| JDK | OpenJDK 17 (`JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64`) |
| Android SDK | `~/Android/Sdk` |
| NDK | Stub at `~/Android/Sdk/ndk/28.2.13676358/` |
| Gradle | 9.1.0 |
| AGP | 9.0.1 |
| Kotlin | 2.3.20 |
| compileSdk | 36 (platform stub based on platform 34 + BAKLAVA) |
| build-tools | 36.0.0 (copy of build-tools 34.0.0) |
| minSdk | 24 |
| targetSdk | 36 |

### 9.2 Target Device

| Component | Value |
|-----------|-------|
| Model | Huawei JKM-LX1 (P Smart 2019) |
| Android | 9 API 28 |
| Arch | arm64-v8a |
| Connection | ADB over TCP/IP (`192.168.11.67:5555`) |

### 9.3 Build Commands

```bash
flutter build apk --debug --split-per-abi
flutter run --debug
adb connect 192.168.11.67:5555
adb logcat -s flutter:* AndroidRuntime:* "*:F"
```

### 9.4 Build Constraints

- Do NOT update Gradle wrapper version
- Do NOT change AGP version
- Do NOT download full NDK or SDK packages
- `android.ndk.suppressMinSdkVersionError=34` in `gradle.properties`
- Release build is stripped; debug build is ~95 MB (arm64-v8a)

---

## 10. Bug Fix Summary

### Fix 1: `_saveInvoice()` — Zero Total on Orders (CRITICAL)

**File:** `lib/driver/screens/invoice_screen.dart`

**Symptom:** After creating an invoice, the order's `final_total` displayed as 0 on the orders list and detail screens.

**Root Cause:** The `orders.update()` call that sets `final_total` was positioned AFTER the `driverOrdersProvider` refresh call. The stream emitted stale data before the DB update persisted.

**Fix:** Moved `orders.update( orderId, {'final_total': totalAmount} )` to execute BEFORE the provider refresh calls (lines were reordered within the try block).

### Fix 2: `_updateInvoice()` — Redundant `orders.update()` Call

**File:** `lib/driver/screens/invoice_screen.dart`

**Symptom:** A second `orders.update()` call duplicated an already-executed update with no additional effect.

**Fix:** Removed the redundant duplicate call.

### Fix 3: `_saveInvoice()` / `_updateInvoice()` — Harmful Provider Invalidations (CRITICAL)

**Files:** `lib/driver/screens/invoice_screen.dart`, `lib/driver/screens/order_detail_screen.dart`

**Symptom (0 EGP on cards):** After invoice creation, dashboard order cards showed `final_total = 0` even though the DB contained the correct value. The `_saveInvoice()` reorder fix (Fix 1) helped but didn't fully resolve it — the race persisted in other code paths.

**Symptom (Accept Order sync):** After accepting an order in `OrderDetailScreen`, the dashboard order list sometimes showed stale status or the order disappeared briefly before reappearing.

**Root Cause:** `ref.invalidate()` and `ref.refresh()` calls on `driverOrdersProvider` (a `StreamProvider` backed by Supabase realtime) were killing the underlying subscription. When the subscription was recreated, it fired before the DB write was committed, returning stale data. The Supabase realtime channel would eventually deliver the correct data, but the race window was visible to the user.

**Fix:**
1. **`invoice_screen.dart`**: Removed `ref.invalidate(driverOrdersProvider)`, `ref.invalidate(detailOrderProvider)`, and `ref.invalidate(detailInvoiceProvider)`. Only screen-local providers (`_invoiceProvider`, `_invoiceOrderProvider`) are invalidated.
2. **`order_detail_screen.dart`**: Removed all `ref.refresh(driverOrdersProvider)` calls from `_acceptOrder()`, `_updateStatus()`, and both invoice button callbacks. Screen-local realtime subscriptions (`_orderRealtimeSub`, `_invoiceRealtimeSub`) handle cross-screen sync.
3. **`driver_providers.dart`**: Changed `driverOrdersProvider` from `StreamProvider.autoDispose` → `StreamProvider` (non-autoDispose) to eliminate unnecessary subscription disposal during navigation.

**Architectural lesson:** Never call `invalidate()`/`refresh()` on StreamProviders backed by Supabase realtime. Let the realtime channel deliver DB changes automatically. If a screen needs immediate feedback after a mutation, invalidate screen-local `FutureProvider`s, not shared stream providers.

### Fix 4: Splash/Loading Desync — Timer-Based Initialization

**File:** `lib/main.dart`

**Symptom:** Splash screen showed orange/blank flash between initialization and the main app. The progress bar advanced on fixed timers, not actual completion events. Sometimes the splash progressed to 100% and then hung before transitioning.

**Root Cause:** Two separate `MaterialApp` widgets (one for splash, one for main app) caused a full widget tree rebuild, creating the flash. Timer-based `_animateTo()` advanced progress without regard to actual init step completion.

**Fix:**
1. Replaced timer-based `_animateTo()` with event-driven `_setProgress()` that jumps to specific milestones when each init step actually completes.
2. Replaced dual-`MaterialApp` widget tree swap with single `MaterialApp` wrapped in `AnimatedSwitcher` — the boot screen (`_SplashApp`) handles initialization, then swaps cleanly to the GoRouter-powered app.
3. Added explicit `currentSession` checkpoint at the auth resolution milestone.
4. GoRouter is only constructed after initialization is fully complete (progress = 1.0).

### Fix 5: Login Routing Glitch — Double Navigation

**Files:** `lib/driver/screens/login_screen.dart`, `lib/driver/screens/splash_screen.dart`, `lib/driver/providers/router_provider.dart`

**Symptom:** After login, the user sometimes saw a brief flash of the dashboard before being redirected back to login, or vice versa. The splash screen always navigated to `/login` regardless of auth state.

**Root Cause:** Multiple competing navigation commands: `login_screen.dart` called `context.go(RoutePaths.dashboard)` after signIn, while GoRouter's redirect simultaneously tried to route based on auth state. The two navigation commands raced. Similarly, `splash_screen.dart` hard-coded `context.go(RoutePaths.login)` in `initState()`, overriding GoRouter's redirect decision.

**Fix:**
1. **`login_screen.dart`**: Removed `context.go(RoutePaths.dashboard)` from `_login()` — GoRouter's redirect handles navigation.
2. **`splash_screen.dart`**: Removed `context.go(RoutePaths.login)` — now a pure pass-through route.
3. **`router_provider.dart`**: Added early-return redirect for splash route (`/splash` → dashboard if authenticated, login if not) before the general auth route check.

---

## 11. Architecture Stabilization: Changes Made

### 11.1 SupabaseClientProvider (NEW)

**File:** `lib/shared/providers/supabase_client_provider.dart`

A single Riverpod provider that exposes `SupabaseClient`:

```dart
final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
```

This replaces all direct `Supabase.instance.client` calls across the codebase. The provider can be overridden in tests with a mock client.

### 11.2 Route Paths Constants (NEW)

**File:** `lib/shared/constants/route_paths.dart`

All route path strings centralized into a single `RoutePaths` class with:
- Static const strings for fixed routes (e.g., `static const login = '/login'`)
- Static methods for parameterized routes (e.g., `static String orderDetail(id) => '/dashboard/order-detail/$id'`)
- All 9+ screen files updated to use constants instead of string literals

### 11.3 Service Layer Refactoring

| Change | Details |
|--------|---------|
| Constructor injection | All 10 services with Supabase dependencies now accept `SupabaseClient` via constructor |
| `other_services.dart` removed | Split into 6 individual files — no remaining references |
| New service files | `notification_service.dart`, `message_service.dart`, `complaint_service.dart`, `rating_service.dart`, `payment_service.dart`, `location_service.dart` |
| All 14 provider definitions updated | Every service instantiation passes `ref.read(supabaseClientProvider)` |
| `Supabase.instance.client` usage | Reduced from 37 → 19 calls (remaining in screen-level business logic, out of scope) |

### 11.4 Auth Provider Refactoring

**File:** `lib/driver/providers/auth_provider.dart`

- `DriverAuthNotifier` now accepts `SupabaseClient` via constructor
- All internal `Supabase.instance.client` calls replaced with `_supabase`
- Provider injects via `ref.read(supabaseClientProvider)`:
  ```dart
  final driverAuthProvider = StateNotifierProvider<DriverAuthNotifier, DriverAuthState>((ref) {
    return DriverAuthNotifier(ref.read(supabaseClientProvider));
  });
  ```

### 11.5 Event-Driven Splash & Boot Initialization

**File:** `lib/main.dart`

Replaced the timer-based splash with an event-driven initialization flow:

- `_setProgress(double value)` advances the progress bar to specific milestones when each init step actually completes (SharedPrefs, Supabase, notifications, auth session check)
- Single `MaterialApp` with `AnimatedSwitcher` replaces the previous two-`MaterialApp` widget-tree-swap — eliminates orange/blank flash
- GoRouter is constructed only after initialization completes (progress reaches 1.0)
- `currentSession` checkpoint added at the auth resolution milestone ensures auth state is resolved before transitioning

```dart
// Before: timer-based, two MaterialApps
_animateTo() { /* fixed durations */ }
// Two separate runApp() pathways with different widget trees

// After: event-driven, single MaterialApp + AnimatedSwitcher
_setProgress(0.10); // after SharedPrefs init
_setProgress(0.30); // after logger init
_setProgress(0.40); // after Supabase init
_setProgress(0.50); // after notifications init
_setProgress(0.70); // after SharedPrefs loaded
_setProgress(0.85); // after auth session check
_setProgress(0.95); // settle delay
_setProgress(1.00); // GoRouter constructed → transition to app
```

### 11.6 Reactive Auth via onAuthStateChange

**File:** `lib/driver/providers/auth_provider.dart`

Added `onAuthStateChange` subscription to `DriverAuthNotifier` for reactive auth state management:

```dart
_authSub = _supabase.auth.onAuthStateChange.listen((authState) {
  if (!state.isLoading) {
    state = DriverAuthState(supabaseUser: authState.session?.user);
  }
});
```

Key behaviors:
- Listener fires on login, logout, token refresh, and session restore
- `isLoading` flag is preserved during active `signIn()` — the listener skips its state update when `isLoading == true` so the signIn method retains full control of the state
- Subscription is cancelled in `dispose()` override

### 11.7 No-autoDispose for driverOrdersProvider

**File:** `lib/driver/providers/driver_providers.dart`

Changed `driverOrdersProvider` from `StreamProvider.autoDispose` to `StreamProvider`:

```dart
// Before:
final driverOrdersProvider = StreamProvider.autoDispose<List<OrderModel>>((ref) { ... });

// After:
final driverOrdersProvider = StreamProvider<List<OrderModel>>((ref) { ... });
```

**Rationale:** The dashboard (parent shell route in GoRouter) watches this provider constantly. `autoDispose` disposed the subscription during navigation, causing unnecessary reconnects and creating race condition windows where data could be stale.

### 11.8 Provider Definitions Updated

All 14 service provider definitions across the codebase updated to inject `SupabaseClient`:

| File | Provider(s) |
|------|-------------|
| `driver_providers.dart` | `driverOrdersProvider`, `driverNotifServiceProvider`, `driverCollectionsServiceProvider`, `driverStoreServiceProvider` |
| `invoice_screen.dart` | `_invoiceServiceProvider`, `_invoiceOrderServiceProvider` |
| `order_detail_screen.dart` | `_detailOrderServiceProvider`, `_detailInvoiceServiceProvider` |
| `collections_screen.dart` | `_collectionsServiceProvider` |
| `qr_code_screen.dart` | `_qrServiceProvider`, `_qrInvoiceServiceProvider` |
| `scan_qr_screen.dart` | `_scanServiceProvider` |
| `chat_screen.dart` | `_chatServiceProvider` |
| `wallet_screen.dart` | `_walletServiceProvider` |

### 11.9 File Count Changes

| Category | Before | After | Change |
|----------|--------|-------|--------|
| Services | 6 files | 13 files | +7 (split, includes pre-existing logger/permission) |
| Providers | 4 files | 8 files | +4 (supabase_client, connectivity, locale, logger were already there) |
| Constants | 0 files | 1 file | +1 (route_paths.dart) |
| `other_services.dart` | 1 file (monolithic) | 0 files | -1 (deleted) |
| `.bak` files | 3 files | 0 files | -3 (cleaned up) |

---

## 12. Dependency Map

```
flutter_riverpod ───────► State management (all screens)
go_router ─────────────► Routing + auth guards

supabase_flutter ──────► Database, Auth, Realtime, Storage
  └── supabaseClientProvider ◄── single source of truth

flutter_map ───────────► OpenStreetMap display
  └── latlong2

mobile_scanner ────────► QR/barcode scanning

flutter_local_notifications ──► Local push notifications

geolocator ────────────► Device location tracking

connectivity_plus ─────► Network state monitoring

share_plus ────────────► Share intent

app_links ─────────────► Deep link handling

flutter_pdfview ───────► PDF invoice viewing

intl ──────────────────► i18n (via AppLocalizations)

path_provider ─────────► File system paths

logger_service.dart ───► (Custom) Structured file logging

shared_preferences ────► Theme/notification preference persistence

route_paths.dart ──────► (Custom) Route string constants
```

---

## 13. Issues & Recommendations (Updated)

### 13.1 Resolved Issues

| Issue | Status | Resolution |
|-------|--------|------------|
| **Dual auth services** | ✅ RESOLVED | `auth_service.dart` no longer exists in codebase; `DriverAuthNotifier` is the sole auth implementation |
| **`other_services.dart` monolithic** | ✅ RESOLVED | Split into 6 individual files with clean imports |
| **Direct `Supabase.instance.client` singletons** | ✅ RESOLVED | All services now accept client via constructor; usage reduced from 37 to 19 calls |
| **Hardcoded route strings** | ✅ RESOLVED | All navigation paths use `RoutePaths.*` constants |
| **Dead `.bak` files** | ✅ RESOLVED | 3 stale `.bak` files deleted |
| **No centralized SupabaseClient** | ✅ RESOLVED | `supabaseClientProvider` is the single source of truth |
| **Unused screens in report** | ✅ RESOLVED | Screen inventory updated to match actual files (20 screens) |
| **`AllScreen` ambiguity** | ✅ RESOLVED | Screen does not exist in codebase |
| **Zero total on orders after invoice** | ✅ RESOLVED | DB update reordered before provider refresh; removed harmful `invalidate()` calls on shared StreamProviders |
| **Accept Order sync race** | ✅ RESOLVED | Removed `ref.refresh(driverOrdersProvider)` from `OrderDetailScreen`; removed `autoDispose` from `driverOrdersProvider` |
| **Splash screen flash/desync** | ✅ RESOLVED | Replaced timer-based `_animateTo()` with event-driven `_setProgress()`; single `MaterialApp` + `AnimatedSwitcher` replaces dual-`MaterialApp` swap |
| **Login routing glitch** | ✅ RESOLVED | Removed manual `context.go()` calls from `login_screen.dart` and `splash_screen.dart`; GoRouter redirect handles all auth routing |
| **`driverOrdersProvider` autoDispose** | ✅ RESOLVED | Changed to non-`autoDispose` `StreamProvider` — dashboard is always in tree, no benefit from disposal |

### 13.2 Remaining Issues

| Issue | Severity | Recommendation |
|-------|----------|----------------|
| **Zero test coverage** | HIGH | Add unit tests for services and widget tests for critical screens (InvoiceScreen, OrderDetailScreen) |
| **No repository layer** | MEDIUM | Screens call services through providers directly. Adding a repository layer would enable offline caching and simplify testing |
| **Mixed state management** | MEDIUM | `InvoiceScreen` uses local `State` for complex form state alongside Riverpod providers. Consider migrating fully to Riverpod for consistency |
| **Screen-local providers duplicated** | MEDIUM | Several screens define their own local service providers (e.g., `_collectionsServiceProvider`, `_walletServiceProvider`) alongside shared ones in `driver_providers.dart`. Consolidate for consistency |
| **Large screen files** | MEDIUM | `invoice_screen.dart` (~873 lines), `order_detail_screen.dart` (~568 lines) mix UI, logic, and data access |
| **Manual serialization** | MEDIUM | All models use hand-written `fromMap()`/`toMap()`. Consider `json_serializable` or `freezed` for generated code |
| **No offline support** | MEDIUM | No local caching strategy. If Supabase is unreachable, the app shows an error state with no fallback |
| **Remaining `Supabase.instance.client` calls** | MEDIUM | 19 calls remain in screen-level business logic (realtime subscriptions, storage uploads, auth operations embedded in StatefulWidgets). Extract into service methods |
| **Dead code** | LOW | `location_service.dart` and `rating_service.dart` exist but are not imported by any screen; split was mechanical |
| **Auth route redirect hardcoded list** | LOW | Auth route check in `router_provider.dart:73` is a hardcoded list of 3 paths; could be a `Set<String>` |
| **Large debug APK** | LOW | 95 MB for arm64-v8a debug build |
| **Platform stub fragility** | MEDIUM | Using Android 36 platform stub built from 34 is fragile |
| **GoRouter splash redirect hardcoded** | LOW | Splash redirect in `router_provider.dart` uses early-return check instead of the general auth route set; consider consolidating |
| **No end-to-end tests for state sync** | MEDIUM | Critical state sync scenarios (invoice creation → dashboard update, accept order → order list update) have no automated verification |

---

## 14. Key Architectural Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| State management | Riverpod 2.x | Compile-time safety, testability, no `BuildContext` dependency |
| Routing | GoRouter | Declarative, auth redirect built-in, deep link support |
| Backend | Supabase | Lower cost than Firebase, PostgreSQL, realtime, RLS |
| Maps | flutter_map (OpenStreetMap) | Free, no API key required |
| SupabaseClient access | **`supabaseClientProvider` (Riverpod)** | Replaced global singleton pattern; enables test mocking, single source of truth |
| Service dependencies | **Constructor injection** | Replaced `Supabase.instance.client` singletons in services; all dependencies explicit |
| Route strings | **`RoutePaths` constants** | Replaced hardcoded strings throughout screens; single point of change |
| Localization | Custom AppLocalizations | Custom implementation with 374 keys in ar/en |
| Logging | Custom file-based | Structured logging to file with log levels + rotation |
| Initialization | **Event-driven splash** | Replaced timer-based `_animateTo()` with milestone-based `_setProgress()`; single `MaterialApp` + `AnimatedSwitcher` |
| Auth reactivity | **onAuthStateChange subscription** | `DriverAuthNotifier` subscribes to Supabase auth state changes for reactive session management |
| StreamProvider lifecycle | **Non-autoDispose for always-watched streams** | `driverOrdersProvider` uses `StreamProvider` (not `.autoDispose`) — the dashboard shell route always exists |
| Cross-screen state sync | **Supabase realtime, not provider invalidation** | Never call `invalidate()`/`refresh()` on shared StreamProviders — realtime subscriptions deliver DB changes automatically; use screen-local providers for immediate feedback |
| Auth routing | **GoRouter redirect only** | Screens never call `context.go()` after auth mutations; `router_provider.dart` redirect handles all auth-based navigation |

---

## 15. File Count & Size Summary

| Category | File Count | Total Lines (approx) |
|----------|-----------|---------------------|
| Driver screens | 20 files | ~6,200 lines |
| Providers | 8 files | ~250 lines |
| Services | 13 files | ~850 lines |
| Models | 5 files | ~700 lines |
| Shared widgets | 6 files | ~500 lines |
| App config (theme, router, constants, locales) | 6 files | ~1,300 lines |
| **Total** | **~58 files** | **~9,800 lines** |

---

## 16. Migration Notes

### 16.1 Adding a New Feature

1. **Create a new service** — follow the constructor injection pattern:
   ```dart
   class MyService {
     final SupabaseClient _supabase;
     MyService(this._supabase);
     Future<void> doThing() => _supabase.from('my_table').insert({...});
   }
   ```

2. **Create a provider** — inject via `supabaseClientProvider`:
   ```dart
   final myProvider = Provider<MyService>((ref) => MyService(ref.read(supabaseClientProvider)));
   ```

3. **Add a route** — add to `RoutePaths` and `router_provider.dart`:
   ```dart
   // In route_paths.dart
   static const String myRoute = '/dashboard/my-route';
   
   // In router_provider.dart
   GoRoute(path: 'my-route', builder: (_, _) => const MyScreen()),
   ```

4. **Create the screen** — import `RoutePaths` for navigation:
   ```dart
   import '../../shared/constants/route_paths.dart';
   // ...
   context.push(RoutePaths.myRoute);
   ```

### 16.2 Testing

- Override `supabaseClientProvider` with a mock `SupabaseClient` for service tests
- All services accept the client via constructor, making them inherently testable
- No refactoring needed to test existing services — just instantiate with a mock

### 16.3 Remaining Architecture Work (Future)

- Extract 19 remaining `Supabase.instance.client` calls from screen StatefulWidgets into service methods
- Consolidate screen-local service providers into `driver_providers.dart` to avoid dual initialization
- Add a repository layer between services and screens for offline caching
- Split `invoice_screen.dart` (~873 lines) into focused components/controllers
- Add end-to-end tests for critical state sync scenarios (invoice creation, order acceptance, status updates)
- Consider extracting `SplashApp` boot sequence into a dedicated service/provider for testability
- Clean up remaining `unused_result` warnings for `ref.refresh()` calls on screen-local providers (informational, not harmful) in `invoice_screen.dart` and `order_detail_screen.dart`
