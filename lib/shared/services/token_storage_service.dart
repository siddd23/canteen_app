import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TokenStorageService {
  TokenStorageService._();

  static final TokenStorageService instance = TokenStorageService._();

  static const String _tokenKey = 'authentication_token';
  static const String _roleKey = 'authenticated_user_role';
  static const String _userIdKey = 'authenticated_user_id';
  static const String _destinationKey = 'authenticated_destination';

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(),
  );

  String? _cachedToken;
  String? _cachedRole;
  String? _cachedUserId;
  String? _cachedDestination;

  Future<void> saveSession({
    required String token,
    required String role,
    required String userId,
    required String destination,
  }) async {
    // Make the new session immediately available to API requests.
    _cachedToken = token;
    _cachedRole = role;
    _cachedUserId = userId;
    _cachedDestination = destination;

    try {
      await Future.wait([
        _storage.write(key: _tokenKey, value: token),
        _storage.write(key: _roleKey, value: role),
        _storage.write(key: _userIdKey, value: userId),
        _storage.write(key: _destinationKey, value: destination),
      ]);
    } catch (error) {
      // Do not leave an in-memory session if persistence fails.
      _cachedToken = null;
      _cachedRole = null;
      _cachedUserId = null;
      _cachedDestination = null;
      rethrow;
    }
  }

  Future<String?> getToken() async {
    if (_cachedToken != null && _cachedToken!.isNotEmpty) {
      return _cachedToken;
    }

    final token = await _storage.read(key: _tokenKey);

    if (token != null && token.isNotEmpty) {
      _cachedToken = token;
    }

    return token;
  }

  Future<String?> getRole() async {
    if (_cachedRole != null && _cachedRole!.isNotEmpty) {
      return _cachedRole;
    }

    final role = await _storage.read(key: _roleKey);

    if (role != null && role.isNotEmpty) {
      _cachedRole = role;
    }

    return role;
  }

  Future<String?> getUserId() async {
    if (_cachedUserId != null && _cachedUserId!.isNotEmpty) {
      return _cachedUserId;
    }

    final userId = await _storage.read(key: _userIdKey);

    if (userId != null && userId.isNotEmpty) {
      _cachedUserId = userId;
    }

    return userId;
  }

  Future<bool> get hasSession async {
    final token = await getToken();
    return token != null && token.isNotEmpty;
  }

  Future<String?> getDestination() async {
    if (_cachedDestination != null && _cachedDestination!.isNotEmpty) {
      return _cachedDestination;
    }

    final destination = await _storage.read(key: _destinationKey);
    if (destination != null && destination.isNotEmpty) {
      _cachedDestination = destination;
    }
    return destination;
  }

  Future<void> saveDestination(String destination) async {
    _cachedDestination = destination;
    await _storage.write(key: _destinationKey, value: destination);
  }

  Future<void> clearSession() async {
    // Remove the session from memory immediately.
    _cachedToken = null;
    _cachedRole = null;
    _cachedUserId = null;
    _cachedDestination = null;

    await Future.wait([
      _storage.delete(key: _tokenKey),
      _storage.delete(key: _roleKey),
      _storage.delete(key: _userIdKey),
      _storage.delete(key: _destinationKey),
    ]);
  }
}
