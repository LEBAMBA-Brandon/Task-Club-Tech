import 'package:dio/dio.dart';

/// Erreur unique remontée par la couche réseau, prête à être affichée.
class ApiException implements Exception {
  ApiException(this.message, {this.statusCode, this.code, this.fieldErrors = const {}, this.isOffline = false});

  /// Message lisible pour l'utilisateur.
  final String message;
  final int? statusCode;

  /// Code métier renvoyé par l'API (EMAIL_NOT_VERIFIED, ACCOUNT_PENDING, ...).
  final String? code;

  /// Erreurs de validation par champ (HTTP 422).
  final Map<String, String> fieldErrors;

  /// Vrai si le serveur est injoignable (pas de réseau).
  final bool isOffline;

  /// Convertit une erreur Dio en ApiException.
  factory ApiException.fromDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ApiException('Serveur injoignable. Vérifiez votre connexion.', isOffline: true);
      default:
        break;
    }

    final response = e.response;
    final data = response?.data;
    final status = response?.statusCode;
    var message = 'Une erreur est survenue ($status).';
    String? code;
    final fields = <String, String>{};

    if (data is Map) {
      if (data['message'] is String) message = data['message'] as String;
      if (data['code'] is String) code = data['code'] as String;
      final errors = data['errors'];
      if (errors is Map) {
        errors.forEach((key, value) {
          if (value is List && value.isNotEmpty) fields[key.toString()] = value.first.toString();
        });
        if (fields.isNotEmpty) message = fields.values.first;
      }
    }
    if (status == 429) message = 'Trop de tentatives. Patientez une minute.';
    if (status != null && status >= 500) message = 'Erreur du serveur. Réessayez plus tard.';

    return ApiException(message, statusCode: status, code: code, fieldErrors: fields);
  }

  @override
  String toString() => message;
}
