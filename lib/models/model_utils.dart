class ModelUtils {
  const ModelUtils._();

  static String string(dynamic value, {String fallback = ''}) {
    if (value == null) return fallback;
    return value.toString();
  }

  static String? nullableString(dynamic value) {
    if (value == null) return null;
    final text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static int integer(dynamic value, {int fallback = 0}) {
    return integerOrNull(value) ?? fallback;
  }

  static int? integerOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  static double? doubleValue(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static bool boolean(dynamic value, {bool fallback = false}) {
    if (value == null) return fallback;
    if (value is bool) return value;
    final normalized = value.toString().trim().toLowerCase();
    if (normalized == 'true' || normalized == '1' || normalized == 'ya') {
      return true;
    }
    if (normalized == 'false' || normalized == '0' || normalized == 'tidak') {
      return false;
    }
    return fallback;
  }

  static DateTime? dateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
    return null;
  }

  static String? isoDate(dynamic value) {
    final parsed = dateTime(value);
    if (parsed == null) return null;
    final normalized = DateTime(parsed.year, parsed.month, parsed.day);
    final month = normalized.month.toString().padLeft(2, '0');
    final day = normalized.day.toString().padLeft(2, '0');
    return '${normalized.year}-$month-$day';
  }

  static String? isoDateTime(DateTime? value) {
    return value?.toUtc().toIso8601String();
  }

  static bool looksLikeUuid(String value) {
    return RegExp(
      r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$',
    ).hasMatch(value.trim());
  }

  static String dayNameFromNumber(int dayNumber) {
    switch (dayNumber) {
      case 1:
        return 'Senin';
      case 2:
        return 'Selasa';
      case 3:
        return 'Rabu';
      case 4:
        return 'Kamis';
      case 5:
        return 'Jumat';
      case 6:
        return 'Sabtu';
      case 7:
        return 'Minggu';
      default:
        return dayNumber.toString();
    }
  }

  static int dayNumber(dynamic value, {int fallback = 1}) {
    if (value == null) return fallback;
    if (value is int) return value;

    final normalized = value.toString().trim().toLowerCase();
    switch (normalized) {
      case '1':
      case 'senin':
      case 'monday':
        return 1;
      case '2':
      case 'selasa':
      case 'tuesday':
        return 2;
      case '3':
      case 'rabu':
      case 'wednesday':
        return 3;
      case '4':
      case 'kamis':
      case 'thursday':
        return 4;
      case '5':
      case 'jumat':
      case 'friday':
        return 5;
      case '6':
      case 'sabtu':
      case 'saturday':
        return 6;
      case '7':
      case 'minggu':
      case 'sunday':
        return 7;
      default:
        return int.tryParse(normalized) ?? fallback;
    }
  }

  static Map<String, dynamic> compact(Map<String, dynamic> map) {
    final result = <String, dynamic>{};
    map.forEach((key, value) {
      if (value != null) {
        result[key] = value;
      }
    });
    return result;
  }

  static String? getWaktuMulai(int jam) {
    switch (jam) {
      case 1:
        return '07.15';
      case 2:
        return '07.55';
      case 3:
        return '08.35';
      case 4:
        return '09.30';
      case 5:
        return '10.10';
      case 6:
        return '10.50';
      case 7:
        return '12.00';
      case 8:
        return '12.40';
      default:
        return null;
    }
  }

  static String? getWaktuSelesai(int jam) {
    switch (jam) {
      case 1:
        return '07.55';
      case 2:
        return '08.35';
      case 3:
        return '09.15';
      case 4:
        return '10.10';
      case 5:
        return '10.50';
      case 6:
        return '11.30';
      case 7:
        return '12.40';
      case 8:
        return '13.20';
      default:
        return null;
    }
  }
}
