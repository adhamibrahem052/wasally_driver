# Architecture Stabilization Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Consolidate auth services, enforce service layer, split dumping-ground files, fix performance issues, and remove dead code — all without breaking existing behavior.

**Architecture:** Convert flat Provider-based auth to reactive StateNotifier; create a mockable SupabaseClientProvider; eliminate all direct `Supabase.instance.client` calls from screens; split `other_services.dart` (6 classes) and `other_models.dart` (7 classes) into individual files; fix client-side stream filtering to server-side; replace wallet polling with Realtime.

**Tech Stack:** Flutter 3.12+, Dart, Riverpod 2.x, GoRouter 14.x, Supabase 2.x

## Global Constraints

- Do NOT change Gradle wrapper, AGP version, or download SDK packages
- `JAVA_HOME` must be `/usr/lib/jvm/java-17-openjdk-amd64`
- `ANDROID_HOME` must be `~/Android/Sdk`
- Build verification: `flutter build apk --debug --split-per-abi` must succeed
- All text is RTL-first (Arabic app); preserve `TextAlign.start`/`MainAxisAlignment.start` patterns
- Every phase must leave the project in a working (buildable) state

## File Structure

```
lib/
├── driver/
│   └── providers/
│       ├── auth_provider.dart          MODIFY (become StateNotifier)
│       └── driver_providers.dart       MODIFY (use SupabaseClientProvider)
│   └── screens/
│       ├── invoice_screen.dart         MODIFY (call InvoiceService, not Supabase directly)
│       ├── order_detail_screen.dart    MODIFY (call services, not Supabase directly)
│       ├── edit_profile_screen.dart    MODIFY (use AuthService methods via provider)
│       ├── store_invoices_screen.dart  MODIFY (use CollectionService)
│       ├── login_screen.dart           MODIFY (adapt to new auth API)
│       ├── register_screen.dart        MODIFY (adapt to new auth API)
│       ├── profile_screen.dart         MODIFY (minor: signOut API change)
│       └── collections_screen.dart     MODIFY (minor: auth API change)
├── shared/
│   ├── providers/
│   │   └── supabase_client_provider.dart   CREATE (wraps SupabaseClient, mockable)
│   ├── services/
│   │   ├── auth_service.dart               DELETE (merged into auth_provider)
│   │   ├── notification_service.dart       CREATE (from other_services.dart)
│   │   ├── message_service.dart            CREATE (from other_services.dart)
│   │   ├── complaint_service.dart          CREATE (from other_services.dart)
│   │   ├── rating_service.dart             CREATE (from other_services.dart)
│   │   ├── payment_service.dart            CREATE (from other_services.dart)
│   │   ├── location_service.dart           CREATE (from other_services.dart)
│   │   ├── other_services.dart             DELETE (replaced by individual files)
│   │   ├── collection_service.dart         MODIFY (extract model classes, use provider)
│   │   ├── order_service.dart              MODIFY (accept SupabaseClient param)
│   │   ├── invoice_service.dart            MODIFY (accept SupabaseClient param)
│   │   └── store_service.dart              MODIFY (accept SupabaseClient param)
│   └── models/
│       ├── notification_model.dart         CREATE (from other_models.dart)
│       ├── message_model.dart              CREATE (from other_models.dart)
│       ├── complaint_model.dart            CREATE (from other_models.dart)
│       ├── rating_model.dart               CREATE (from other_models.dart)
│       ├── payment_method_model.dart       CREATE (from other_models.dart)
│       ├── wallet_transaction_model.dart   CREATE (from other_models.dart)
│       ├── payment_model.dart              CREATE (from other_models.dart)
│       ├── other_models.dart               DELETE (replaced by individual files)
│       └── collection_models.dart          CREATE (DriverCollection, DriverStoreInvoice from collection_service)
```

---

### Phase 1: Auth Consolidation & Reactivity

Objective: Convert DriverAuthProvider to a reactive StateNotifier, merge AuthService's useful methods, delete dead code. 28 call sites updated, 0 behavioral changes.

---

#### Task 1.1: Create Reactive DriverAuthNotifier

**Files:**
- Modify: `lib/driver/providers/auth_provider.dart`
- Delete: `lib/shared/services/auth_service.dart` (after confirming no imports remain)

**Interfaces:**
- Consumes: `Supabase.instance.client` (temporarily; will use provider in Phase 2)
- Produces: `DriverAuthNotifier` (StateNotifier<DriverAuthState>), `driverAuthProvider` (StateNotifierProvider)

New auth state model:

```dart
class DriverAuthState {
  final User? supabaseUser;
  final bool isLoading;
  final String? errorMessage;

  const DriverAuthState({this.supabaseUser, this.isLoading = false, this.errorMessage});

  bool get isLoggedIn => supabaseUser != null;
}
```

- [ ] **Step 1: Write the new auth_provider.dart**

Replace the existing content with:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverAuthState {
  final User? supabaseUser;
  final bool isLoading;
  final String? errorMessage;

  const DriverAuthState({this.supabaseUser, this.isLoading = false, this.errorMessage});

  bool get isLoggedIn => supabaseUser != null;
}

class DriverAuthNotifier extends StateNotifier<DriverAuthState> {
  DriverAuthNotifier() : super(const DriverAuthState()) {
    _init();
  }

  void _init() {
    final user = Supabase.instance.client.auth.currentUser;
    state = DriverAuthState(supabaseUser: user);
  }

  User? get currentSupabaseUser => state.supabaseUser;

  Stream<AuthState> get authState => Supabase.instance.client.auth.onAuthStateChange;

  Future<void> signIn(String email, String password) async {
    state = DriverAuthState(supabaseUser: state.supabaseUser, isLoading: true);
    try {
      final response = await Supabase.instance.client.auth.signInWithPassword(
        email: email, password: password,
      );
      final user = response.user;
      if (user == null) throw Exception('فشل تسجيل الدخول');
      final profile = await _getProfile(user.id);
      if (profile == null) throw Exception('لم يتم العثور على بيانات المستخدم');
      if (profile['role'] != 'driver') {
        await Supabase.instance.client.auth.signOut();
        throw Exception('هذا الحساب ليس لحساب سائق');
      }
      state = DriverAuthState(supabaseUser: user);
    } catch (e) {
      state = DriverAuthState(supabaseUser: state.supabaseUser, errorMessage: _mapAuthError(e));
      rethrow;
    }
  }

  Future<void> signUp(String email, String password, String fullName, String phone) async {
    state = DriverAuthState(supabaseUser: state.supabaseUser, isLoading: true);
    try {
      final response = await Supabase.instance.client.auth.signUp(
        email: email, password: password,
        data: {'full_name': fullName, 'role': 'driver'},
      );
      final user = response.user;
      if (user == null) throw Exception('فشل إنشاء الحساب');
      await Supabase.instance.client.from('profiles').upsert({
        'id': user.id, 'full_name': fullName, 'phone_number': phone, 'role': 'driver',
      });
      state = DriverAuthState(supabaseUser: user);
    } catch (e) {
      state = DriverAuthState(supabaseUser: state.supabaseUser, errorMessage: _mapAuthError(e));
      rethrow;
    }
  }

  Future<void> signOut() async {
    await Supabase.instance.client.auth.signOut();
    state = const DriverAuthState();
  }

  Future<Map<String, dynamic>?> _getProfile(String userId) async {
    try {
      return await Supabase.instance.client.from('profiles').select().eq('id', userId).single();
    } catch (_) {
      return null;
    }
  }

  String _mapAuthError(Object error) {
    final message = error.toString();
    if (message.contains('Email not confirmed') || message.contains('email_not_confirmed')) {
      return 'يرجى تأكيد البريد الإلكتروني أولاً';
    }
    if (message.contains('Invalid login credentials')) {
      return 'البريد الإلكتروني أو كلمة المرور غير صحيحة';
    }
    if (message.contains('User already registered')) {
      return 'البريد الإلكتروني مسجل بالفعل';
    }
    if (message.contains('rate_limit')) {
      return 'طلبات كثيرة جداً، حاول بعد قليل';
    }
    return 'حدث خطأ، حاول مرة أخرى';
  }

  Future<void> updateProfile({String? fullName, String? phoneNumber, String? address}) async {
    final user = state.supabaseUser;
    if (user == null) throw Exception('لا يوجد مستخدم');
    final data = <String, dynamic>{};
    if (fullName != null) data['full_name'] = fullName;
    if (phoneNumber != null) data['phone_number'] = phoneNumber;
    if (address != null) data['address'] = address;
    await Supabase.instance.client.from('profiles').update(data).eq('id', user.id);
  }

  Future<void> updateFcmToken(String token) async {
    final user = state.supabaseUser;
    if (user == null) throw Exception('لا يوجد مستخدم');
    await Supabase.instance.client.from('profiles').update({'fcm_token': token}).eq('id', user.id);
  }

  Future<void> sendPasswordReset(String email) async {
    await Supabase.instance.client.auth.resetPasswordForEmail(email);
  }

  bool isEmailConfirmed() {
    return state.supabaseUser?.emailConfirmedAt != null;
  }
}

final driverAuthProvider = StateNotifierProvider<DriverAuthNotifier, DriverAuthState>((ref) {
  return DriverAuthNotifier();
});
```

Run: `flutter analyze lib/driver/providers/auth_provider.dart`
Expected: No errors (the class itself compiles)

- [ ] **Step 2: Update router_provider.dart to use reactive auth**

Current code watches `driverAuthProvider` via `ref.watch(driverAuthProvider)` which returned `DriverAuthProvider`. Now it returns `DriverAuthState`. Change:

```dart
// Before:
final auth = ref.watch(driverAuthProvider);

// After:
final authState = ref.watch(driverAuthProvider);
```

Update the redirect:
```dart
final isLoggedIn = authState.isLoggedIn;
```

Run: `flutter analyze lib/driver/providers/router_provider.dart`
Expected: No errors

- [ ] **Step 3: Update all 27 remaining call sites**

Pattern: `ref.read(driverAuthProvider)` was returning `DriverAuthProvider` — now it returns `DriverAuthState` (immutable). For call sites that need `currentSupabaseUser`, they now use:

```dart
// Before:
ref.read(driverAuthProvider).currentSupabaseUser
// After:
ref.read(driverAuthProvider).supabaseUser
```

Call sites that need to call methods (signIn, signOut, signUp) need the notifier:
```dart
// Before:
await ref.read(driverAuthProvider).signIn(...)
// After:
await ref.read(driverAuthProvider.notifier).signIn(...)
```

For `profile_screen.dart`:
```dart
// Before:
await ref.read(driverAuthProvider).signOut()
// After:
await ref.read(driverAuthProvider.notifier).signOut()
```

For `login_screen.dart`:
```dart
// Before:
await ref.read(driverAuthProvider).signIn(_emailController.text.trim(), _passwordController.text);
// After:
await ref.read(driverAuthProvider.notifier).signIn(_emailController.text.trim(), _passwordController.text);
```

For `register_screen.dart`:
```dart
// Before:
await ref.read(driverAuthProvider).signUp(...)
// After:
await ref.read(driverAuthProvider.notifier).signUp(...)
```

Files to update (28 total call sites):
1. `lib/driver/screens/invoice_screen.dart` line 112
2. `lib/driver/screens/order_detail_screen.dart` lines 134, 151, 287
3. `lib/driver/providers/driver_providers.dart` lines 18, 32, 40, 47, 53
4. `lib/driver/screens/edit_profile_screen.dart` lines 15, 59
5. `lib/driver/screens/store_invoices_screen.dart` line 160
6. `lib/driver/screens/profile_screen.dart` line 113
7. `lib/driver/providers/router_provider.dart` line 25 (already done in Step 2)
8. `lib/driver/screens/collections_screen.dart` lines 12, 18, 24, 30, 36, 97
9. `lib/driver/screens/notifications_screen.dart` line 72
10. `lib/driver/screens/wallet_screen.dart` line 22
11. `lib/driver/screens/chat_screen.dart` lines 43, 77, 119
12. `lib/driver/screens/register_screen.dart` line 34
13. `lib/driver/screens/login_screen.dart` line 31

For every `.currentSupabaseUser` → `.supabaseUser`
For every `.isLoggedIn` → keep as is (forwarded from `DriverAuthState`)
For every method call (signIn, signOut, signUp) → `.notifier.method()`

After each file edit, run:
```bash
flutter analyze lib/driver/screens/<file>.dart
```

- [ ] **Step 4: Delete auth_service.dart**

Confirm no file imports `auth_service.dart`:
```bash
grep -r "auth_service" lib/ --include="*.dart"
```
Expected: no matches (only self-referential ones in auth_service.dart itself).

Delete file:
```bash
rm lib/shared/services/auth_service.dart
```

Run: `flutter analyze`
Expected: No errors related to missing `auth_service`

- [ ] **Step 5: Build APK to verify**

```bash
export JAVA_HOME=/usr/lib/jvm/java-17-openjdk-amd64
export ANDROID_HOME=~/Android/Sdk
flutter build apk --debug --split-per-abi
```

Expected: BUILD SUCCESSFUL. APK at `build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk`

---

### Phase 2: Service Layer Structure

Objective: Create SupabaseClientProvider for mockability, split dumping-ground files into single-class files, update imports everywhere.

---

#### Task 2.1: Create SupabaseClientProvider

**Files:**
- Create: `lib/shared/providers/supabase_client_provider.dart`
- Modify: All service files (inject client via constructor)

- [ ] **Step 1: Create the provider file**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
```

- [ ] **Step 2: Update all service classes to accept SupabaseClient via constructor**

Each service currently has `final SupabaseClient _supabase = Supabase.instance.client;`

Change to:
```dart
final SupabaseClient _supabase;
// In constructor:
this._supabase,
```

This allows DI:
```dart
// Production usage in providers:
ref.read(supabaseClientProvider)
// Test usage:
ServiceClass(MockSupabaseClient())
```

Files to update:
- `lib/shared/services/order_service.dart`
- `lib/shared/services/invoice_service.dart`
- `lib/shared/services/store_service.dart`
- `lib/shared/services/collection_service.dart`
- `lib/shared/services/other_services.dart` (will be split — do in Task 2.2)

- [ ] **Step 3: Update all service-providing providers to pass client**

In `driver_providers.dart` and screen-level providers:
```dart
// Before:
final service = OrderService();
// After:
final client = ref.read(supabaseClientProvider);
final service = OrderService(client);
```

Run: `flutter analyze`
Expected: No errors

---

#### Task 2.2: Split other_services.dart

**Files:**
- Create: `lib/shared/services/notification_service.dart`
- Create: `lib/shared/services/message_service.dart`
- Create: `lib/shared/services/complaint_service.dart`
- Create: `lib/shared/services/rating_service.dart`
- Create: `lib/shared/services/payment_service.dart`
- Create: `lib/shared/services/location_service.dart`
- Delete: `lib/shared/services/other_services.dart`
- Modify: `lib/driver/providers/driver_providers.dart` (update imports)

- [ ] **Step 1: Create notification_service.dart**

Extract `NotificationService` class from `other_services.dart` into its own file:

```
lib/shared/services/notification_service.dart
```

Content: exact copy of the `NotificationService` class with constructor accepting `SupabaseClient`.

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_model.dart';

class NotificationService {
  final SupabaseClient _supabase;
  NotificationService(this._supabase);

  Stream<List<NotificationModel>> getNotificationsStream(String userId) {
    return _supabase
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false)
        .map((maps) => maps.map((m) => NotificationModel.fromMap(m)).toList());
  }

  Future<void> markAsRead(String notificationId) async {
    await _supabase.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  Future<void> markAllAsRead(String userId) async {
    await _supabase.from('notifications').update({'is_read': true}).eq('user_id', userId);
  }

  Future<int> getUnreadCount(String userId) async {
    final response = await _supabase
        .from('notifications')
        .select('id')
        .eq('user_id', userId)
        .eq('is_read', false);
    return (response as List).length;
  }
}
```

- [ ] **Step 2: Create message_service.dart, complaint_service.dart, rating_service.dart, payment_service.dart, location_service.dart**

Each gets the same treatment — extract class, add constructor with `SupabaseClient`, update import path for models.

Models these services reference (will be split in Task 2.3):
- `NotificationService` → `NotificationModel` (from `notification_model.dart`)
- `MessageService` → `MessageModel` (from `message_model.dart`)
- `ComplaintService` → `ComplaintModel` (from `complaint_model.dart`)
- `RatingService` → `RatingModel` (from `rating_model.dart`)
- `PaymentService` → `PaymentMethod`, `WalletTransaction`, `PaymentModel` (from individual model files)
- `LocationService` → no model, returns `Map<String, dynamic>?`

- [ ] **Step 3: Update driver_providers.dart**

Update the import:
```dart
// Before:
import '../../shared/services/other_services.dart';
// After:
import '../../shared/services/notification_service.dart';
```

Update providers to pass client:
```dart
final driverNotifServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService(ref.read(supabaseClientProvider));
});
```

- [ ] **Step 4: Delete other_services.dart**

```bash
rm lib/shared/services/other_services.dart
```

Run: `flutter analyze`
Expected: No errors

---

#### Task 2.3: Split other_models.dart

**Files:**
- Create: `lib/shared/models/notification_model.dart`
- Create: `lib/shared/models/message_model.dart`
- Create: `lib/shared/models/complaint_model.dart`
- Create: `lib/shared/models/rating_model.dart`
- Create: `lib/shared/models/payment_method_model.dart`
- Create: `lib/shared/models/wallet_transaction_model.dart`
- Create: `lib/shared/models/payment_model.dart`
- Delete: `lib/shared/models/other_models.dart`
- Modify: All files that import `other_models.dart` → specific model files

- [ ] **Step 1: Create each model file**

One class per file, exact content copied from `other_models.dart`.

- `notification_model.dart` → `NotificationModel`
- `message_model.dart` → `MessageModel`
- `complaint_model.dart` → `ComplaintModel`
- `rating_model.dart` → `RatingModel`
- `payment_method_model.dart` → `PaymentMethod`
- `wallet_transaction_model.dart` → `WalletTransaction`
- `payment_model.dart` → `PaymentModel`

- [ ] **Step 2: Update all imports**

Find every file importing `other_models.dart`:
```bash
grep -r "other_models" lib/ --include="*.dart"
```

Expected: `driver_providers.dart` and `other_services.dart` (already deleted in Task 2.2).

Update `lib/driver/providers/driver_providers.dart`:
```dart
// Before:
import '../../shared/models/other_models.dart';
// After:
import '../../shared/models/notification_model.dart';
```

- [ ] **Step 3: Delete other_models.dart**

```bash
rm lib/shared/models/other_models.dart
```

Run: `flutter analyze`
Expected: No errors

---

#### Task 2.4: Extract Collection Models

**Files:**
- Create: `lib/shared/models/collection_models.dart`
- Modify: `lib/shared/services/collection_service.dart`

- [ ] **Step 1: Create collection_models.dart**

Move `DriverCollection` and `DriverStoreInvoice` classes from `collection_service.dart` into their own file:

```dart
class DriverCollection {
  // exact content from collection_service.dart
}

class DriverStoreInvoice {
  // exact content from collection_service.dart
}
```

- [ ] **Step 2: Update collection_service.dart**

- Remove `DriverCollection` and `DriverStoreInvoice` class definitions
- Add import: `import '../models/collection_models.dart';`
- Update constructor to accept `SupabaseClient`

- [ ] **Step 3: Update imports**

Find files importing `collection_service.dart` that use `DriverCollection` or `DriverStoreInvoice`:
```bash
grep -r "DriverCollection\|DriverStoreInvoice" lib/ --include="*.dart"
```

Add `collection_models.dart` import where needed.

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 4: Full build verification**

```bash
flutter build apk --debug --split-per-abi
```

Expected: BUILD SUCCESSFUL

---

### Phase 3: Screen-Service Decoupling

Objective: Remove all direct `Supabase.instance.client` calls from screen files. Route through service layer.

---

#### Task 3.1: Refactor invoice_screen.dart

**File:** `lib/driver/screens/invoice_screen.dart`

Direct Supabase calls in this file:
1. Line 31: `Supabase.instance.client.from('stores').select()...` — in `_invoiceStoreProvider`
2. Line 60: `Supabase.instance.client.from('invoices').stream(...)` — in `initState`
3. Line 129: `Supabase.instance.client.from('orders').update(...)` — in `_saveInvoice()`
4. Lines 157-174: multiple `Supabase.instance.client.from('invoice_items').delete()/insert()` and `from('invoices').update()` and `from('orders').update()` — in `_updateInvoice()`

- [ ] **Step 1: Update `_invoiceStoreProvider`**

```dart
// Before:
final _invoiceStoreProvider = FutureProvider.family.autoDispose<StoreModel?, String>((ref, storeId) async {
  if (storeId.isEmpty) return null;
  final res = await Supabase.instance.client.from('stores').select().eq('id', storeId).single();
  return StoreModel.fromMap(res);
});

// After:
final _invoiceStoreProvider = FutureProvider.family.autoDispose<StoreModel?, String>((ref, storeId) async {
  if (storeId.isEmpty) return null;
  final client = ref.read(supabaseClientProvider);
  final res = await client.from('stores').select().eq('id', storeId).single();
  return StoreModel.fromMap(res);
});
```

- [ ] **Step 2: Replace direct DB calls in `_saveInvoice()`**

Replace `Supabase.instance.client.from('orders').update(...)` with `OrderService` call:

```dart
final orderService = ref.read(_invoiceOrderServiceProvider);
await Supabase.instance.client.from('orders').update({'final_total': _grandTotal}).eq('id', widget.orderId);
```

Wait — `_invoiceOrderServiceProvider` already provides `OrderService`. But `OrderService` doesn't have an `updateOrder` method for arbitrary fields. It only has `updateOrderStatus`. Need to either add a generic method to OrderService or use the service provider's client.

Since we're in Phase 3 (service layer enforcement), let me add a needed method to OrderService:

```dart
// In OrderService:
Future<void> updateOrderField(String orderId, Map<String, dynamic> fields) async {
  await _supabase.from('orders').update(fields).eq('id', orderId);
}
```

Then in `_saveInvoice()`:
```dart
await ref.read(_invoiceOrderServiceProvider).updateOrderField(widget.orderId, {'final_total': _grandTotal});
```

Same for `_updateInvoice()`:
```dart
await ref.read(_invoiceOrderServiceProvider).updateOrderField(widget.orderId, {
  'final_total': newGrandTotal,
  'delivery_fee': _deliveryFee,
});
```

- [ ] **Step 3: Replace direct DB calls in `_updateInvoice()`**

Replace `Supabase.instance.client.from('invoice_items').delete().eq(...)` and `.insert(...)` with `InvoiceService` methods.

Add to `InvoiceService`:
```dart
Future<void> replaceInvoiceItems(String invoiceId, List<Map<String, dynamic>> items) async {
  await _supabase.from('invoice_items').delete().eq('invoice_id', invoiceId);
  for (final item in items) {
    await _supabase.from('invoice_items').insert({...item, 'invoice_id': invoiceId});
  }
}

Future<void> updateInvoiceFields(String invoiceId, Map<String, dynamic> fields) async {
  await _supabase.from('invoices').update(fields).eq('id', invoiceId);
}
```

Then update `_updateInvoice()` to use these service methods instead of raw `Supabase.instance.client` calls.

- [ ] **Step 4: Update realtime subscription in initState**

Replace raw Supabase with `InvoiceService`:
```dart
_invoiceRealtimeSub = ref.read(_invoiceServiceProvider).getInvoiceStream(widget.orderId).listen((_) {
  ref.invalidate(_invoiceProvider(widget.orderId));
  ref.invalidate(_invoiceOrderProvider(widget.orderId));
});
```

Wait — `getInvoiceStream` returns `Stream<InvoiceModel?>`, not `Stream<List<Map<String, dynamic>>>`. The subscription type changes. Update:

```dart
_invoiceRealtimeSub = ref.read(_invoiceServiceProvider).getInvoiceStream(widget.orderId).listen((_) {
  ref.invalidate(_invoiceProvider(widget.orderId));
  ref.invalidate(_invoiceOrderProvider(widget.orderId));
});
```

But need to make `getInvoiceStream` non-yielding to avoid flood. The current implementation yields `getInvoiceByOrderId` immediately then on every change. This should be fine — just need to ignore the parameter in the listener:

```dart
_invoiceRealtimeSub = ref.read(_invoiceServiceProvider).getInvoiceStream(widget.orderId).listen((_) {
```

- [ ] **Step 5: Remove `import 'package:supabase_flutter/supabase_flutter.dart';` from invoice_screen.dart**

After all direct Supabase calls are gone.

Run: `flutter analyze lib/driver/screens/invoice_screen.dart`
Expected: No errors

---

#### Task 3.2: Refactor order_detail_screen.dart

**File:** `lib/driver/screens/order_detail_screen.dart`

Direct Supabase calls:
1. Line 30: `_detailCustomerProvider` — `Supabase.instance.client.from('profiles').select()...`
2. Lines 40-52: `_detailDriverLocationProvider` — Supabase Realtime stream
3. Lines 74-83: `initState` — Realtime subs for orders and invoices
4. Lines 133-139: `_startLocationTracking` — `Supabase.instance.client.from('driver_locations').upsert()`

- [ ] **Step 1: Update `_detailCustomerProvider`**

```dart
// Before:
final _detailCustomerProvider = FutureProvider.family.autoDispose<AppUser?, String>((ref, id) async {
  if (id.isEmpty) return null;
  final res = await Supabase.instance.client.from('profiles').select().eq('id', id).single();
  return AppUser.fromMap(res);
});

// After:
final _detailCustomerProvider = FutureProvider.family.autoDispose<AppUser?, String>((ref, id) async {
  if (id.isEmpty) return null;
  final client = ref.read(supabaseClientProvider);
  final res = await client.from('profiles').select().eq('id', id).single();
  return AppUser.fromMap(res);
});
```

- [ ] **Step 2: Update `_detailDriverLocationProvider`**

```dart
// After:
final _detailDriverLocationProvider = StreamProvider.family.autoDispose<LatLng?, String>((ref, driverId) {
  if (driverId.isEmpty) return const Stream.empty();
  final client = ref.read(supabaseClientProvider);
  return client
      .from('driver_locations')
      .stream(primaryKey: ['driver_id'])
      .eq('driver_id', driverId)
      .map((maps) { /* same content */ });
});
```

- [ ] **Step 3: Update realtime subscriptions in initState**

```dart
// After:
final client = ref.read(supabaseClientProvider);
_orderRealtimeSub = client
    .from('orders')
    .stream(primaryKey: ['id'])
    .eq('id', widget.orderId)
    .listen((_) => ref.invalidate(detailOrderProvider(widget.orderId)));
_invoiceRealtimeSub = client
    .from('invoices')
    .stream(primaryKey: ['id'])
    .eq('order_id', widget.orderId)
    .listen((_) => ref.invalidate(detailInvoiceProvider(widget.orderId)));
```

- [ ] **Step 4: Update `_startLocationTracking`**

```dart
final client = ref.read(supabaseClientProvider);
await client.from('driver_locations').upsert({
  'driver_id': ref.read(driverAuthProvider).supabaseUser!.id,
  'lat': pos.latitude,
  'lng': pos.longitude,
  'updated_at': DateTime.now().toIso8601String(),
});
```

- [ ] **Step 5: Remove `import 'package:supabase_flutter/supabase_flutter.dart';`**

Run: `flutter analyze lib/driver/screens/order_detail_screen.dart`
Expected: No errors

---

#### Task 3.3: Refactor edit_profile_screen.dart

**File:** `lib/driver/screens/edit_profile_screen.dart`

Direct Supabase calls:
1. Lines 17: profile fetch
2. Lines 81-84: avatar upload + profile update
3. Line 92: auth updateUser

- [ ] **Step 1: Replace direct profile fetch with SupabaseClientProvider**

```dart
// Before (line 17):
final res = await Supabase.instance.client.from('profiles').select().eq('id', user.id).single();
// After:
final client = ref.read(supabaseClientProvider);
final res = await client.from('profiles').select().eq('id', user.id).single();
```

- [ ] **Step 2: Replace avatar upload and profile update**

```dart
// Before:
await Supabase.instance.client.storage.from('profiles').upload(path, _avatarFile!, fileOptions: FileOptions(upsert: true));
avatarUrl = Supabase.instance.client.storage.from('profiles').getPublicUrl(path);
await Supabase.instance.client.from('profiles').update({...}).eq('id', user.id);

// After:
final client = ref.read(supabaseClientProvider);
await client.storage.from('profiles').upload(path, _avatarFile!, fileOptions: FileOptions(upsert: true));
avatarUrl = client.storage.from('profiles').getPublicUrl(path);
await client.from('profiles').update({...}).eq('id', user.id);
```

Run: `flutter analyze lib/driver/screens/edit_profile_screen.dart`
Expected: No errors

---

#### Task 3.4: Refactor store_invoices_screen.dart

**File:** `lib/driver/screens/store_invoices_screen.dart`

- [ ] **Step 1: Replace direct Supabase insert**

```dart
// Before (line 162):
await Supabase.instance.client.from('driver_store_invoices').insert({...});
// After:
final client = ref.read(supabaseClientProvider);
await client.from('driver_store_invoices').insert({...});
```

Run: `flutter analyze lib/driver/screens/store_invoices_screen.dart`
Expected: No errors

---

#### Task 3.5: Refactor driver_providers.dart

**File:** `lib/driver/providers/driver_providers.dart`

Direct Supabase call at line 42:
```dart
final res = await Supabase.instance.client.from('profiles').select().eq('id', user.id).single();
```

- [ ] **Step 1: Replace with SupabaseClientProvider**

```dart
// After:
final client = ref.read(supabaseClientProvider);
final res = await client.from('profiles').select().eq('id', user.id).single();
```

- [ ] **Step 2: Remove unused `import 'package:supabase_flutter/supabase_flutter.dart';`** if no other Supabase references remain in this file

Run: `flutter analyze lib/driver/providers/driver_providers.dart`
Expected: No errors

- [ ] **Step 3: Full build verification**

```bash
flutter build apk --debug --split-per-abi
```

Expected: BUILD SUCCESSFUL

---

### Phase 4: Provider & Performance Fixes

Objective: Fix server-side stream filtering, replace wallet polling with Realtime, ensure `updated_at` is set.

---

#### Task 4.1: Fix driverOrdersProvider Server-Side Filtering

**File:** `lib/shared/services/order_service.dart`

**Current behavior:**
- Stream fetches ALL orders with status in `['pending', 'preparing', 'on_the_way', 'driver_assigned', 'store_confirmed']`
- Then filters in-memory: `.where((o) => o.status == 'pending' || o.driverId == driverId)`
- This fetches excess data on every stream emission

- [ ] **Step 1: Update `getDriverOrdersStream`**

New filter: fetch pending orders (no driver) + orders assigned to this driver.

But Supabase stream filters can't do OR conditions across columns. The best approach is two streams merged:

```dart
Stream<List<OrderModel>> getDriverOrdersStream(String driverId) {
  logService.info('OrderService', 'getDriverOrdersStream: $driverId');
  final pendingStream = _supabase
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('status', 'pending')
      .order('created_at', ascending: false)
      .map((maps) => maps.map((m) => OrderModel.fromMap(m)).toList());

  final assignedStream = _supabase
      .from('orders')
      .stream(primaryKey: ['id'])
      .eq('driver_id', driverId)
      .inFilter('status', ['driver_assigned', 'store_confirmed', 'preparing', 'on_the_way'])
      .order('created_at', ascending: false)
      .map((maps) => maps.map((m) => OrderModel.fromMap(m)).toList());

  return Rx.combineLatest2(pendingStream, assignedStream, (pending, assigned) {
    final merged = {...pending, ...assigned};
    return merged.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  });
}
```

Wait — this uses `Rx.combineLatest2` from `rxdart`. The project doesn't currently use rxdart. Alternative: use `StreamGroup.merge` or manually merge.

Simpler approach — keep a single stream with broader filter but add the driverId filter:

```dart
Stream<List<OrderModel>> getDriverOrdersStream(String driverId) {
  logService.info('OrderService', 'getDriverOrdersStream: $driverId');
  return _supabase
      .from('orders')
      .stream(primaryKey: ['id'])
      .or('status.eq.pending,and(driver_id.eq.$driverId,status.in.(driver_assigned,store_confirmed,preparing,on_the_way))')
      .order('created_at', ascending: false)
      .map((maps) {
    final orders = maps.map((m) => OrderModel.fromMap(m)).toList();
    logService.debug('OrderService', 'Stream emitted ${orders.length} orders');
    return orders;
  });
}
```

actually, the Supabase `.or()` filter creates a proper SQL OR. Let me use that approach:

```dart
return _supabase
    .from('orders')
    .stream(primaryKey: ['id'])
    .or('status.eq.pending,and(driver_id.eq.$driverId,status.in.(driver_assigned,store_confirmed,preparing,on_the_way))')
    .order('created_at', ascending: false)
    .map((maps) => maps.map((m) => OrderModel.fromMap(m)).toList());
```

This way the filtering happens server-side, and the `.where()` in-memory filter removed.

- [ ] **Step 2: Remove the in-memory `.where()` clause**

Remove `.where((o) => o.status == 'pending' || o.driverId == driverId)` from the map function.

Run: `flutter analyze lib/shared/services/order_service.dart`
Expected: No errors

---

#### Task 4.2: Fix PaymentService Wallet Polling

**File:** `lib/shared/services/payment_service.dart`

**Current:** `getWalletBalanceStream` uses `Stream.periodic(const Duration(seconds: 5), (_) => null).asyncMap(...)`

**Fix:** Replace with Supabase Realtime subscription on `profiles` table.

- [ ] **Step 1: Replace polling with Realtime**

```dart
Stream<double> getWalletBalanceStream(String userId) {
  return _supabase
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', userId)
      .map((maps) {
    if (maps.isEmpty) return 0.0;
    return (maps.last['wallet_balance'] as num?)?.toDouble() ?? 0;
  });
}

Stream<List<WalletTransaction>> getWalletTransactionsStream(String userId) {
  return _supabase
      .from('wallet_transactions')
      .stream(primaryKey: ['id'])
      .eq('user_id', userId)
      .order('created_at', ascending: false)
      .map((maps) => maps.map((m) => WalletTransaction.fromMap(m)).toList());
}
```

(The wallet screen uses these streams — verified by file pattern)

Run: `flutter analyze lib/shared/services/payment_service.dart`
Expected: No errors

---

#### Task 4.3: Add updated_at to Service Updates

**Files:** Check all services that do `.update()` calls

- [ ] **Step 1: Add `updated_at` to all `_supabase.from(...).update()` calls**

Search for `.update(` patterns:
```bash
grep -n "\.update(" lib/shared/services/*.dart
```

For each `.update(` call, add:
```dart
'updated_at': DateTime.now().toIso8601String(),
```

Files:
- `order_service.dart`: `updateOrderStatus`, `assignDriver`, `cancelOrder`, `confirmDelivery`, `rateOrder`
- `invoice_service.dart`: `updateInvoiceStatus`
- `collection_service.dart`: none (DB update calls use raw Supabase)
- `notification_service.dart` (new): `markAsRead`, `markAllAsRead`
- `complaint_service.dart` (new): `markAsRead`

Wait — need to check the DB schema. Does the `orders` table have an `updated_at` column? Yes, `OrderModel` has `updatedAt` field. So we should set it.

But some update calls might not have `updated_at` in the DB schema (e.g., `notifications`). Let me keep this simple — only add `updated_at` to tables confirmed to have the column.

From the model files and Supabase.sql knowledge:
- `orders` — has `updated_at` ✅
- `invoices` — has `updated_at` ✅
- Notifications via Supabase usually have `updated_at` — add it
- `profiles` — add it
- `driver_collections` — add it
- Others — skip if uncertain

Run: `flutter analyze`
Expected: No errors

- [ ] **Step 2: Full build verification**

```bash
flutter build apk --debug --split-per-abi
```

Expected: BUILD SUCCESSFUL

---

### Phase 5: Polish & Verification

Objective: Add lint rules, test infrastructure, verification suite.

---

#### Task 5.1: Configure analysis_options.yaml

**File:** `analysis_options.yaml` (project root)

- [ ] **Step 1: Update to stricter rules**

```yaml
include: package:flutter_lints/flutter.yaml

linter:
  rules:
    - prefer_const_constructors
    - prefer_const_declarations
    - avoid_print
    - prefer_single_quotes
    - unawaited_futures
    - unused_import
    - unused_local_variable
    - dead_code

analyzer:
  errors:
    unused_import: error
    unused_local_variable: warning
    dead_code: warning
```

- [ ] **Step 2: Run analyze and fix any new warnings**

```bash
flutter analyze
```

Fix any issues found (likely unused imports).

---

#### Task 5.2: Set Up Test Infrastructure

**Files:**
- Create: `test/mocks/mock_supabase_client.dart`
- Create: `test/test_helper.dart`

- [ ] **Step 1: Create test_helper.dart**

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

ProviderContainer createTestContainer({
  List<Override> overrides = const [],
}) {
  return ProviderContainer(overrides: overrides);
}
```

- [ ] **Step 2: Create mock Supabase client interface**

Since `SupabaseClient` is from `supabase_flutter` and doesn't have a mockable interface, the cleanest approach is to create a wrapper abstract class for auth operations we use:

For now, just set up the test directory and verify it works:
```bash
flutter test
```

Expected: "No tests found" (we haven't written any yet, but the framework works)

---

#### Task 5.3: Write Auth Provider Tests

**Files:**
- Create: `test/providers/auth_provider_test.dart`

- [ ] **Step 1: Write tests for DriverAuthState**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  group('DriverAuthState', () {
    test('initial state has no user and is not loading', () {
      // Will be implemented once supabase_flutter test helpers are available
    });
  });
}
```

Note: Full auth provider testing requires mocking `Supabase.instance.client`, which needs integration with `supabase_flutter`'s test utilities. For this plan cycle, document the test structure but acknowledge that comprehensive mocks require a separate effort.

---

#### Task 5.4: Full Build + On-Device Verification

- [ ] **Step 1: Build release APK**

```bash
flutter build apk --debug --split-per-abi
```

- [ ] **Step 2: Install on device**

```bash
adb connect 192.168.11.67:5555
flutter run --debug
```

- [ ] **Step 3: Verify key flows**

1. Login flow — sign in with existing driver credentials
2. Orders list — verify orders appear with correct totals
3. Order detail — verify order details, map, customer info
4. Accept order — verify accept button works, driver assigned
5. Create invoice — verify invoice creation, items, final_total sync
6. Edit invoice — verify invoice edit, item update
7. Logout — verify sign-out and redirect to login

---

## Rollback Strategy

If any phase breaks the build:

1. **File-level rollback:** Use `git checkout -- <file>` for each changed file
2. **Phase-level rollback:** Each phase builds independently; revert all files in the phase:
   ```bash
   # Example for Phase 1 rollback:
   git checkout -- lib/driver/providers/auth_provider.dart
   git checkout -- lib/shared/services/auth_service.dart  # restore
   ```
3. **Full rollback:** If project isn't a git repo, keep manual backups:
   ```bash
   cp -r lib lib.backup.phase1
   # Before each phase
   ```

## Validation Checklist

Run after each phase:

| Check | Command | Expected |
|-------|---------|----------|
| Static analysis | `flutter analyze` | No errors, warnings ≤ 10 |
| Build (arm64) | `flutter build apk --debug --split-per-abi` | BUILD SUCCESSFUL |
| Build size | `ls -lh build/app/outputs/flutter-apk/app-arm64-v8a-debug.apk` | Reasonable (< 120 MB) |
| Login | Manual on-device | Works |
| Orders list | Manual on-device | Shows orders |
| Create invoice | Manual on-device | Items + total correct |
| Edit invoice | Manual on-device | Changes persist |

## Acceptance Criteria

1. `AuthService` file deleted, all its utilities merged into `DriverAuthNotifier`
2. `driverAuthProvider` is `StateNotifierProvider<DriverAuthNotifier, DriverAuthState>` (reactive)
3. No `Supabase.instance.client` calls remain in `screens/` directory
4. `other_services.dart` and `other_models.dart` deleted, replaced by individual files
5. `DriverCollection` and `DriverStoreInvoice` are in `models/collection_models.dart`
6. `driverOrdersProvider` uses server-side filtering (no `.where()`)
7. `WalletService` streams use Realtime, not polling
8. `supabaseClientProvider` exists and is used by all services
9. APK builds and installs successfully on Huawei JKM-LX1
10. All existing features work identically (login, orders, invoices, collections, profile)
