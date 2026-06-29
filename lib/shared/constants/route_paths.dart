class RoutePaths {
  static const String splash = '/splash';
  static const String login = '/login';
  static const String register = '/register';
  static const String dashboard = '/dashboard';
  static const String dashboardOrders = '/dashboard/orders';
  static const String dashboardNotifications = '/dashboard/notifications';
  static const String dashboardCollections = '/dashboard/collections';
  static const String dashboardProfile = '/dashboard/profile';
  static const String dashboardEditProfile = '/dashboard/edit-profile';
  static const String dashboardSettings = '/dashboard/settings';
  static const String dashboardAbout = '/dashboard/about';
  static const String dashboardTerms = '/dashboard/terms';
  static const String dashboardStoreInvoices = '/dashboard/store-invoices';
  static const String dashboardLogs = '/dashboard/logs';

  static String dashboardOrderDetail(String id) => '/dashboard/order-detail/$id';
  static String dashboardInvoice(String orderId, String customerId) => '/dashboard/invoice/$orderId/$customerId';
  static String dashboardChat(String orderId, String customerId) => '/dashboard/chat/$orderId/$customerId';
  static String dashboardQrCode(String orderId) => '/dashboard/qr-code/$orderId';
}
