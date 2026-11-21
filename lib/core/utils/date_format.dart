import 'package:intl/intl.dart';

/// Formats de date en français.
class DateFormatter {
  DateFormatter._();

  static final _full = DateFormat('d MMM yyyy à HH:mm', 'fr_FR');
  static final _time = DateFormat('HH:mm', 'fr_FR');
  static final _day = DateFormat('d MMM', 'fr_FR');

  static String full(DateTime date) => _full.format(date.toLocal());

  /// « à l'instant », « il y a 5 min », « 14:32 », « hier », « 12 nov. »
  static String relative(DateTime date) {
    final local = date.toLocal();
    final diff = DateTime.now().difference(local);
    if (diff.inMinutes < 1) return "à l'instant";
    if (diff.inMinutes < 60) return 'il y a ${diff.inMinutes} min';
    if (diff.inHours < 24 && DateTime.now().day == local.day) return _time.format(local);
    if (diff.inDays < 2) return 'hier';
    return _day.format(local);
  }
}
