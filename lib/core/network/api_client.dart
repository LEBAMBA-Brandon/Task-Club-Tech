import 'package:dio/dio.dart';

import '../config/app_config.dart';
import 'api_exception.dart';

/// Client HTTP unique de l'application.
///
/// - ajoute le jeton Sanctum (« Authorization: Bearer ... ») à chaque requête ;
/// - transforme toutes les erreurs en [ApiException] ;
/// - prévient l'application (callback [onUnauthorized]) quand le jeton est expiré (HTTP 401).
class ApiClient {
  ApiClient({required String? Function() tokenReader, this.onUnauthorized})
      : _dio = Dio(BaseOptions(
          baseUrl: AppConfig.apiUrl,
          connectTimeout: AppConfig.connectTimeout,
          receiveTimeout: AppConfig.receiveTimeout,
          headers: {'Accept': 'application/json', 'Content-Type': 'application/json'},
        )) {
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) {
        final token = tokenReader();
        if (token != null) options.headers['Authorization'] = 'Bearer $token';
        handler.next(options);
      },
      onError: (error, handler) {
        if (error.response?.statusCode == 401 && error.requestOptions.headers.containsKey('Authorization')) {
          onUnauthorized?.call();
        }
        handler.next(error);
      },
    ));
  }

  final Dio _dio;
  void Function()? onUnauthorized;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get(path, queryParameters: _clean(query)));

  Future<dynamic> post(String path, [Object? body]) => _send(() => _dio.post(path, data: body));

  Future<dynamic> put(String path, [Object? body]) => _send(() => _dio.put(path, data: body));

  Future<dynamic> patch(String path, [Object? body]) => _send(() => _dio.patch(path, data: body));

  Future<dynamic> delete(String path) => _send(() => _dio.delete(path));

  Future<dynamic> _send(Future<Response> Function() call) async {
    try {
      final response = await call();
      return response.data;
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  /// Retire les paramètres vides de la requête.
  Map<String, dynamic>? _clean(Map<String, dynamic>? query) =>
      query?..removeWhere((_, v) => v == null || (v is String && v.isEmpty));
}
