/// Lenient readers of decoded JSON, shared by the models and `parseWebhook`.
///
/// The server mixes types for the same field (`"1442.330"` vs `1023.41`,
/// `"1520"` vs `1520`) and sends empty maps as PHP `[]`; these helpers absorb
/// that so the models never throw on a shape quirk.
library;

/// JSON object as a map; `{}` for `[]` (PHP empty map), `null` or other types.
Map<String, Object?> asMap(Object? value) =>
    value is Map ? value.cast<String, Object?>() : const {};

/// JSON array as a list; `[]` for anything else.
List<Object?> asList(Object? value) =>
    value is List ? value.cast<Object?>() : const [];

/// Number from a number or a numeric string; `null` when missing or not numeric.
double? asDouble(Object? value) {
  if (value is num) return value.isFinite ? value.toDouble() : null;
  if (value is String && value.trim().isNotEmpty) {
    final n = double.tryParse(value.trim());
    return n != null && n.isFinite ? n : null;
  }
  return null;
}

/// Integer from an int, an integral double or a numeric string; else `null`.
int? asInt(Object? value) {
  if (value is int) return value;
  final d = asDouble(value);
  return d != null && d == d.truncateToDouble() ? d.toInt() : null;
}

/// String from a string or a number; else `null`.
String? asString(Object? value) {
  if (value is String) return value;
  if (value is int) return value.toString();
  if (value is double) {
    return value == value.truncateToDouble()
        ? value.toInt().toString()
        : value.toString();
  }
  return null;
}

/// Boolean from a bool, `1`/`0` or `"1"`/`"true"`; [fallback] otherwise.
bool asBool(Object? value, [bool fallback = false]) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  if (value is String) {
    if (value == '1' || value == 'true') return true;
    if (value == '0' || value == 'false' || value.isEmpty) return false;
  }
  return fallback;
}

/// Map with integer keys (country codes, rent days); non-numeric keys and
/// values that [read] rejects (`null`) are skipped.
Map<int, T> intKeyed<T>(Object? value, T? Function(Object? value) read) {
  final out = <int, T>{};
  asMap(value).forEach((key, raw) {
    final k = int.tryParse(key);
    final v = read(raw);
    if (k != null && v != null) out[k] = v;
  });
  return out;
}

/// Map with string keys; values that [read] rejects (`null`) are skipped.
Map<String, T> stringKeyed<T>(Object? value, T? Function(Object? value) read) {
  final out = <String, T>{};
  asMap(value).forEach((key, raw) {
    final v = read(raw);
    if (v != null) out[key] = v;
  });
  return out;
}

/// List of [read] results; items it rejects (`null`) are skipped.
List<T> listOf<T>(Object? value, T? Function(Object? value) read) => [
      for (final raw in asList(value))
        if (read(raw) case final T v) v,
    ];

/// List of objects parsed by [fromJson]; non-object items are skipped.
List<T> objects<T>(
  Object? value,
  T Function(Map<String, Object?> json) fromJson,
) =>
    [
      for (final raw in asList(value))
        if (raw is Map) fromJson(raw.cast<String, Object?>()),
    ];
