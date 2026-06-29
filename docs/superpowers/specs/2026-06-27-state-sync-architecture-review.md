# State Sync Architecture Review & Implementation Plan

## Problem Summary

4 persistent UX/state sync issues in `wasally_driver`:

1. **Splash/Init Desync** — Blank/orange screen flash; progress bar detached from readiness
2. **Login Routing Glitch** — Brief login screen re-render after successful login
3. **0 EGP on Order Cards** — `final_total` shows 0 even after invoice creation
4. **Accept Order Sync** — Status change doesn't propagate to dashboard/orders list

## Root Causes (Architecture Review)

### Issue 1: Splash/Init
- Timer-based progress bar (`Future.delayed` with fixed percentages) — detached from actual milestones
- `DriverAuthNotifier._init()` checks `_supabase.auth.currentUser` once synchronously; never subscribes to `onAuthStateChange`
- `_SplashApp` (plain `MaterialApp`) → `WasallyDriverApp` (`MaterialApp.router`) transition causes full widget tree rebuild
- `LocaleNotifier` and `AppTheme` call `SharedPreferences.getInstance()` directly (bypassing boot-loaded `_prefs`)

### Issue 2: Login Routing
- Double navigation: GoRouter redirect fires when `isLoggedIn` becomes true, then `_login()` calls `context.go(RoutePaths.dashboard)` again
- Second `context.go()` executes while first navigation is in progress → login screen briefly re-renders

### Issue 3: 0 EGP
- `ref.invalidate()` / `ref.refresh()` on `StreamProvider.autoDispose` (`driverOrdersProvider`) KILLS the realtime subscription
- New subscription does initial fetch — timing gap between DB write and new subscription's fetch
- Realtime subscription would have delivered the update automatically if left alone
- Screen-local providers (`_invoiceProvider` in invoice_screen vs `detailInvoiceProvider` in order_detail_screen) are separate caches

### Issue 4: Accept Order Sync
- Same pattern: `ref.refresh(driverOrdersProvider)` kills realtime subscription
- `assignDriver()` updates DB → realtime would auto-emit → but subscription was killed
- `_updateStatus()` has the same problem

## Implementation Plan (Approach C — Hybrid)

### Phase 1: Event-Driven Splash + Auth Reactivity

**Files:** `main.dart`, `auth_provider.dart`, `router_provider.dart`

**1a. main.dart** — Replace timer-based progress with event-driven milestones:
- Add `_readiness` enum/list of milestones
- Advance progress only when each milestone completes:
  - Supabase initialized
  - SharedPreferences loaded
  - Auth state resolved (session checked)
- Keep splash visible until first navigation settles (add a small grace delay)

**1b. auth_provider.dart** — Add `onAuthStateChange` subscription:
- In `_init()`, subscribe to `_supabase.auth.onAuthStateChange`
- On session restore or sign-in event, update state
- On sign-out event, clear state
- Cancel subscription in `dispose()` (StateNotifier dispose override)

### Phase 2: Remove Double Navigation on Login

**File:** `login_screen.dart`

**2a.** Remove `context.go(RoutePaths.dashboard)` from `_login()` method (line 33)
- GoRouter's `redirect` already handles navigation on `isLoggedIn` state change
- `_login()` should only handle the error case (show dialog) and loading state
- Keep the `setState` for `_isLoading` — that's still needed

### Phase 3: Stop Killing Stream Subscriptions

**Files:** `invoice_screen.dart`, `order_detail_screen.dart`

**3a. invoice_screen.dart — `_saveInvoice()`:**
- Remove `ref.invalidate(driverOrdersProvider)` — realtime stream auto-updates
- Remove `ref.invalidate(detailOrderProvider(...))` — realtime `_orderRealtimeSub` in order_detail_screen handles this
- Remove `ref.invalidate(detailInvoiceProvider(...))` — realtime `_invoiceRealtimeSub` handles this
- Keep `ref.invalidate(_invoiceProvider(...))` — this is the invoice screen's own provider, needs re-fetch
- Keep `ref.invalidate(_invoiceOrderProvider(...))` — same, screen's own provider

**3b. invoice_screen.dart — `_updateInvoice()`:**
- Same removals: `driverOrdersProvider`, `detailOrderProvider`, `detailInvoiceProvider`
- Keep `_invoiceProvider` invalidation

**3c. order_detail_screen.dart — `_acceptOrder()`:**
- Remove `ref.refresh(driverOrdersProvider)` — realtime auto-updates
- Keep `ref.refresh(detailOrderProvider(...))` — FutureProvider needs re-fetch
- Note: `detailOrderProvider` is refreshed (not invalidated) here because `_acceptOrder` has `_isUpdating` state that needs to resolve before the widget rebuilds with fresh data

**3d. order_detail_screen.dart — `_updateStatus()`:**
- Remove `ref.refresh(driverOrdersProvider)` — same reasoning
- Keep `ref.refresh(detailOrderProvider(...))` — FutureProvider needs re-fetch

**3e. order_detail_screen.dart — Invoice button callbacks (lines 501-505, 518-522):**
- Remove `ref.refresh(driverOrdersProvider)` from both
- These are post-navigation callbacks; the realtime stream covers dashboard updates

### Phase 4: Remove `autoDispose` from `driverOrdersProvider`

**File:** `driver_providers.dart`

**4a.** Change `StreamProvider.autoDispose` to `StreamProvider`
- `driverOrdersProvider` is watched by `DriverDashboardScreen` (parent shell route, always in tree)
- `autoDispose` adds zero benefit here and creates disposal risk during navigation
- Without `autoDispose`, `ref.invalidate()` doesn't immediately recreate — it just marks stale, and the stream continues delivering realtime updates

### Phase 5: Verification

- `flutter analyze` — 0 errors
- `flutter build apk --debug` — builds successfully
- Install on device and verify each issue

## Files Changed Summary

| File | Changes |
|------|---------|
| `main.dart` | Event-driven progress milestones |
| `auth_provider.dart` | `onAuthStateChange` subscription, dispose override |
| `router_provider.dart` | Transition delay to let first route settle |
| `login_screen.dart` | Remove `context.go()` from `_login()` |
| `invoice_screen.dart` | Remove `invalidate` on driverOrdersProvider, detailOrderProvider, detailInvoiceProvider |
| `order_detail_screen.dart` | Remove `refresh` on driverOrdersProvider from acceptOrder, updateStatus, invoice callbacks |
| `driver_providers.dart` | `StreamProvider.autoDispose` → `StreamProvider` |

## Risk Assessment

- **Low risk:** Removing `context.go()` from login, removing stream refreshes from order_detail and invoice screens
- **Medium risk:** `onAuthStateChange` subscription — must handle dispose correctly to avoid memory leaks
- **Low risk:** `autoDispose` removal — dashboard is always in tree, no impact on memory
- **Medium risk:** event-driven splash — must test blank-screen flash is resolved, not introduced
