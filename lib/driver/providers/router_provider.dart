import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../shared/constants/route_paths.dart';
import '../../shared/providers/locale_provider.dart';
import '../screens/splash_screen.dart';
import '../screens/login_screen.dart';
import '../screens/register_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/orders_screen.dart';
import '../screens/order_detail_screen.dart';
import '../screens/notifications_screen.dart';
import '../screens/collections_screen.dart';
import '../screens/chat_screen.dart';
import '../screens/invoice_screen.dart';
import '../screens/qr_code_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/edit_profile_screen.dart';
import '../screens/settings_screen.dart';
import '../screens/about_screen.dart';
import '../screens/terms_screen.dart';
import '../screens/store_invoices_screen.dart';
import '../screens/log_viewer_screen.dart';
import 'auth_provider.dart';

final driverRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(driverAuthProvider);
  ref.watch(localeProvider);
  return GoRouter(
    initialLocation: RoutePaths.splash,
    debugLogDiagnostics: false,
    routes: [
      GoRoute(path: RoutePaths.splash, builder: (_, _) => const DriverSplashScreen()),
      GoRoute(path: RoutePaths.login, builder: (_, _) => const DriverLoginScreen()),
      GoRoute(path: RoutePaths.register, builder: (_, _) => const DriverRegisterScreen()),
      GoRoute(
        path: RoutePaths.dashboard,
        builder: (_, _) => const DriverDashboardScreen(),
        routes: [
          GoRoute(path: 'orders', builder: (_, _) => const DriverOrdersScreen()),
          GoRoute(path: 'order-detail/:id', builder: (_, state) => DriverOrderDetailScreen(orderId: state.pathParameters['id']!)),
          GoRoute(path: 'notifications', builder: (_, _) => const DriverNotificationsScreen()),
          GoRoute(path: 'collections', builder: (_, _) => const DriverCollectionsScreen()),
          GoRoute(
            path: 'invoice/:orderId/:customerId',
            builder: (_, state) => DriverInvoiceScreen(
              orderId: state.pathParameters['orderId']!,
              customerId: state.pathParameters['customerId']!,
            ),
          ),
          GoRoute(
            path: 'chat/:orderId/:customerId',
            builder: (_, state) => DriverChatScreen(
              orderId: state.pathParameters['orderId']!,
              customerId: state.pathParameters['customerId']!,
            ),
          ),
          GoRoute(
            path: 'qr-code/:orderId',
            builder: (_, state) => DriverQrCodeScreen(orderId: state.pathParameters['orderId']!),
          ),
          GoRoute(path: 'profile', builder: (_, _) => const DriverProfileScreen()),
          GoRoute(path: 'edit-profile', builder: (_, _) => const DriverEditProfileScreen()),
          GoRoute(path: 'settings', builder: (_, _) => const DriverSettingsScreen()),
          GoRoute(path: 'about', builder: (_, _) => const DriverAboutScreen()),
          GoRoute(path: 'terms', builder: (_, _) => const DriverTermsScreen()),
          GoRoute(path: 'store-invoices', builder: (_, _) => const DriverStoreInvoicesScreen()),
          GoRoute(path: 'logs', builder: (_, _) => const LogViewerScreen()),
        ],
      ),
    ],
    redirect: (context, state) {
      final isLoggedIn = auth.isLoggedIn;
      // Splash is the initial route — immediately redirect based on auth state
      if (state.matchedLocation == RoutePaths.splash) {
        return isLoggedIn ? RoutePaths.dashboard : RoutePaths.login;
      }
      final isAuthRoute = state.matchedLocation == RoutePaths.login || state.matchedLocation == RoutePaths.register;
      if (!isLoggedIn && !isAuthRoute) return RoutePaths.login;
      if (isLoggedIn && isAuthRoute) return RoutePaths.dashboard;
      return null;
    },
  );
});
