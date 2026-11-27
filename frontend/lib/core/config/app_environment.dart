// lib/core/config/app_environment.dart

class AppEnvironment {
  AppEnvironment._();

  /// Default local development base URL for the backend API
  static const String _defaultLocalhostBaseUrl = 'http://localhost:8080';

  /// Production Render cloud backend URL
  static const String productionBackendUrl = 'https://two6-1-biznext.onrender.com';

  /// Base URL for the BizNext Backend REST API.
  /// Defaults to localhost:8080 for local development.
  /// Overridden in production via:
  ///   --dart-define=BACKEND_BASE_URL=https://two6-1-biznext.onrender.com
  /// or legacy:
  ///   --dart-define=BIZNEXT_API_BASE_URL=https://two6-1-biznext.onrender.com/api/customers
  static String get backendBaseUrl {
    const fromEnv = String.fromEnvironment('BACKEND_BASE_URL');
    if (fromEnv.isNotEmpty) {
      return _trimTrailingSlash(fromEnv);
    }

    const legacyEnv = String.fromEnvironment('BIZNEXT_API_BASE_URL');
    if (legacyEnv.isNotEmpty) {
      final trimmed = _trimTrailingSlash(legacyEnv);
      if (trimmed.endsWith('/api/customers')) {
        return trimmed.substring(0, trimmed.length - '/api/customers'.length);
      }
      return trimmed;
    }

    return _defaultLocalhostBaseUrl;
  }

  /// Customer API endpoint URL
  static String get customersApiUrl {
    const legacyEnv = String.fromEnvironment('BIZNEXT_API_BASE_URL');
    if (legacyEnv.isNotEmpty) {
      return _trimTrailingSlash(legacyEnv);
    }
    return '$backendBaseUrl/api/customers';
  }

  /// Sync API endpoint base URL
  static String get syncApiUrl {
    const syncEnv = String.fromEnvironment('SYNC_API_BASE_URL');
    if (syncEnv.isNotEmpty) {
      return _trimTrailingSlash(syncEnv);
    }
    return 'http://localhost:8000/api/v1';
  }

  /// Auto-update API endpoint base URL
  static String get autoUpdateApiUrl {
    const updateEnv = String.fromEnvironment('UPDATE_API_BASE_URL');
    if (updateEnv.isNotEmpty) {
      return _trimTrailingSlash(updateEnv);
    }
    return 'http://localhost:8000/api/v1';
  }

  static String _trimTrailingSlash(String url) {
    return url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }
}
