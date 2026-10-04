class ApiConstants {
  // Change this to your server IP when testing on real device
  // For Android emulator: 10.0.2.2
  // For iOS simulator: localhost
  // For real device: your PC's local IP (e.g., 192.168.1.100)
  static String baseUrl = 'http://10.0.2.2:8000/api/v1';

  // Auth endpoints
  static const String login = '/auth/token/';
  static const String refreshToken = '/auth/token/refresh/';
  static const String register = '/auth/register/';

  // Device endpoints
  static const String devices = '/devices/';
  static const String deviceRegister = '/devices/register/';
  static const String devicePair = '/devices/pair/';

  // Child data endpoints (relative, device_id will be interpolated)
  static String deviceApps(String deviceId) => '/devices/$deviceId/apps/';
  static String deviceApp(String deviceId, String appId) =>
      '/devices/$deviceId/apps/$appId/';
  static String deviceLocations(String deviceId) =>
      '/devices/$deviceId/locations/';
  static String deviceUsage(String deviceId) => '/devices/$deviceId/usage/';
  static String deviceNotifications(String deviceId) =>
      '/devices/$deviceId/notifications/';
  static String deviceAccessibility(String deviceId) =>
      '/devices/$deviceId/accessibility/';
  static String deviceZones(String deviceId) =>
      '/devices/$deviceId/zones/';
  static String deviceContacts(String deviceId) =>
      '/devices/$deviceId/contacts/';
  static String deviceTimeLimits(String deviceId) =>
      '/devices/$deviceId/time-limits/';
  static String deviceSOS(String deviceId) =>
      '/devices/$deviceId/sos/';

  // Sync
  static const String syncBatch = '/sync/batch/';
}
