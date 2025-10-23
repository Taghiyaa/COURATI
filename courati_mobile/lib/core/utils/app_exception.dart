class AppException implements Exception {
  final String message;
  final String? code;

  AppException(this.message, [this.code]);

  @override
  String toString() => message;
}

class NetworkException extends AppException {
  NetworkException([String message = 'Erreur de réseau']) : super(message);
}

class ServerException extends AppException {
  final int statusCode;
  
  ServerException(String message, this.statusCode) : super(message);
}

class AuthException extends AppException {
  AuthException([String message = 'Erreur d\'authentification']) : super(message);
}

class ValidationException extends AppException {
  ValidationException([String message = 'Erreur de validation']) : super(message);
}

// lib/core/utils/date_utils.dart
import 'package:intl/intl.dart';

class AppDateUtils {
  static const String dateFormat = 'dd/MM/yyyy';
  static const String dateTimeFormat = 'dd/MM/yyyy HH:mm';
  static const String timeFormat = 'HH:mm';

  static String formatDate(DateTime date) {
    return DateFormat(dateFormat).format(date);
  }

  static String formatDateTime(DateTime dateTime) {
    return DateFormat(dateTimeFormat).format(dateTime);
  }

  static String formatTime(DateTime dateTime) {
    return DateFormat(timeFormat).format(dateTime);
  }

  static DateTime? parseDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return null;
    try {
      return DateFormat(dateFormat).parse(dateString);
    } catch (e) {
      return null;
    }
  }

  static String timeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 365) {
      return '${(difference.inDays / 365).floor()} an${(difference.inDays / 365).floor() > 1 ? 's' : ''}';
    } else if (difference.inDays > 30) {
      return '${(difference.inDays / 30).floor()} mois';
    } else if (difference.inDays > 0) {
      return '${difference.inDays} jour${difference.inDays > 1 ? 's' : ''}';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} heure${difference.inHours > 1 ? 's' : ''}';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''}';
    } else {
      return 'À l\'instant';
    }
  }
}
