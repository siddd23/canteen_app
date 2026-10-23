import 'package:flutter/foundation.dart';

abstract final class ApiConstants {
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000/api',
  );

  static const Duration timeout = Duration(seconds: 20);

  static void validateConfiguration() {
    if (!kReleaseMode) return;

    final uri = Uri.tryParse(baseUrl);
    final validProductionUrl = uri != null &&
        uri.scheme == 'https' &&
        uri.host.isNotEmpty &&
        uri.host != 'localhost' &&
        uri.host != '127.0.0.1' &&
        uri.host != '10.0.2.2';

    if (!validProductionUrl) {
      throw StateError(
        'Release builds require an HTTPS API_BASE_URL supplied with '
        '--dart-define.',
      );
    }
  }

  static String get realtimeUrl =>
      baseUrl.endsWith('/api') ? baseUrl.substring(0, baseUrl.length - 4) : baseUrl;

  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String session = '/session';

  static const String canteens = '/canteens';
  static const String offices = '/offices';
  static const String orders = '/orders';
  static const String publicOrders = '/public/orders';
  static const String account = '/account';
  static const String customers = '/customers';

  static const String pendingOwners = '/admin/owners/pending';
  static const String owners = '/admin/owners';
  static const String adminOverview = '/admin/owners/overview';
}
