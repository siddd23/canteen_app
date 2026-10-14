import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../../core/constants/api_constants.dart';
import '../../core/utils/api_exception.dart';
import 'token_storage_service.dart';

class ApiService {
  ApiService._();

  static final ApiService instance = ApiService._();

  final http.Client _client = http.Client();

  Uri _createUri(String endpoint, [Map<String, dynamic>? queryParameters]) {
    final uri = Uri.parse('${ApiConstants.baseUrl}$endpoint');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    return uri.replace(
      queryParameters: queryParameters.map(
        (key, value) => MapEntry(key, value.toString()),
      ),
    );
  }

  Future<Map<String, String>> _createHeaders({
    required bool authenticated,
  }) async {
    final headers = <String, String>{
      HttpHeaders.acceptHeader: 'application/json',
      HttpHeaders.contentTypeHeader: 'application/json',
    };

    if (authenticated) {
      final token = await TokenStorageService.instance.getToken();

      if (token == null || token.isEmpty) {
        throw const ApiException(
          message: 'Your session has expired. Please log in again.',
          statusCode: 401,
        );
      }

      headers[HttpHeaders.authorizationHeader] = 'Bearer $token';
    }

    return headers;
  }

  Future<Map<String, dynamic>> get(
    String endpoint, {
    bool authenticated = true,
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      final response = await _client
          .get(
            _createUri(endpoint, queryParameters),
            headers: await _createHeaders(authenticated: authenticated),
          )
          .timeout(ApiConstants.timeout);

      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(message: 'The server took too long to respond.');
    } on SocketException {
      throw const ApiException(
        message:
            'Cannot connect to the server. Check your network and backend URL.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Unable to connect to the backend server.',
      );
    }
  }

  Future<Map<String, dynamic>> post(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    try {
      final response = await _client
          .post(
            _createUri(endpoint),
            headers: await _createHeaders(authenticated: authenticated),
            body: jsonEncode(body ?? {}),
          )
          .timeout(ApiConstants.timeout);

      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(message: 'The server took too long to respond.');
    } on SocketException {
      throw const ApiException(
        message:
            'Cannot connect to the server. Check your network and backend URL.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Unable to connect to the backend server.',
      );
    }
  }

  Future<Map<String, dynamic>> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    try {
      final response = await _client
          .patch(
            _createUri(endpoint),
            headers: await _createHeaders(authenticated: authenticated),
            body: jsonEncode(body ?? {}),
          )
          .timeout(ApiConstants.timeout);

      return _handleResponse(response);
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(message: 'The server took too long to respond.');
    } on SocketException {
      throw const ApiException(
        message:
            'Cannot connect to the server. Check your network and backend URL.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Unable to connect to the backend server.',
      );
    }
  }

  Future<Map<String, dynamic>> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    bool authenticated = true,
  }) async {
    try {
      final request = http.Request('DELETE', _createUri(endpoint))
        ..headers.addAll(
          await _createHeaders(authenticated: authenticated),
        )
        ..body = jsonEncode(body ?? {});
      final streamed = await _client.send(request).timeout(ApiConstants.timeout);
      return _handleResponse(await http.Response.fromStream(streamed));
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw const ApiException(message: 'The server took too long to respond.');
    } on SocketException {
      throw const ApiException(
        message:
            'Cannot connect to the server. Check your network and backend URL.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Unable to connect to the backend server.',
      );
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    Map<String, dynamic> decodedResponse = {};

    if (response.body.isNotEmpty) {
      final decodedBody = jsonDecode(response.body);

      if (decodedBody is Map<String, dynamic>) {
        decodedResponse = decodedBody;
      }
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decodedResponse;
    }

    throw ApiException(
      message:
          decodedResponse['message']?.toString() ??
          'Something went wrong. Please try again.',
      statusCode: response.statusCode,
      errors: decodedResponse['errors'] is List
          ? decodedResponse['errors'] as List
          : const [],
    );
  }

  void close() {
    _client.close();
  }
}
