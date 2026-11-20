import '../json.dart';

/// One SMS of a rent.
final class RentSms {
  /// Creates an SMS entry.
  const RentSms({
    required this.id,
    required this.service,
    required this.text,
    required this.code,
    required this.createdAt,
  });

  /// Parses a `messages` item.
  factory RentSms.fromJson(Map<String, Object?> json) => RentSms(
        id: asInt(json['id']) ?? 0,
        service: asString(json['service']) ?? '',
        text: asString(json['text']) ?? '',
        code: asString(json['code']) ?? '',
        createdAt: asString(json['created_at']) ?? '',
      );

  /// Message id.
  final int id;

  /// Sender. `notify`: a notice about a prohibited sender (does not confirm
  /// the rent).
  final String service;

  /// Full text.
  final String text;

  /// Code extracted from the text; empty when there is none. The integer `0`
  /// the server sends for a `notify` SMS becomes `'0'`.
  final String code;

  /// Arrival time.
  final String createdAt;
}

/// A rent operation.
final class RentItem {
  /// Creates a rent.
  const RentItem({
    required this.tzid,
    required this.status,
    required this.number,
    required this.country,
    required this.sum,
    required this.days,
    required this.hours,
    required this.time,
    required this.extension,
    required this.startTime,
    required this.stopTime,
    required this.extend,
    required this.messages,
    this.timeSeconds,
    this.guardIntervalRemainingSeconds,
    this.daysAutoextend,
    this.checkedTime,
    this.checked,
    this.freeze,
    this.dayExtend,
    this.webhookUrl,
  });

  /// Parses a rent item; `sum` from a number or a decimal string, `extend`
  /// from `[]`.
  factory RentItem.fromJson(Map<String, Object?> json) => RentItem(
        tzid: asInt(json['tzid']) ?? 0,
        status: asInt(json['status']) ?? 0,
        number: asString(json['number']) ?? '',
        country: asInt(json['country']) ?? 0,
        sum: asDouble(json['sum']) ?? 0,
        days: asInt(json['days']) ?? 0,
        hours: asInt(json['hours']) ?? 0,
        time: asInt(json['time']) ?? 0,
        timeSeconds: asInt(json['time_seconds']),
        guardIntervalRemainingSeconds:
            asInt(json['guard_interval_remaining_seconds']),
        extension: asInt(json['extension']) ?? 0,
        daysAutoextend: asInt(json['days_autoextend']),
        startTime: asString(json['start_time']) ?? '',
        stopTime: asString(json['stop_time']) ?? '',
        checkedTime: asString(json['checked_time']),
        checked: json['checked'] == null ? null : asBool(json['checked']),
        freeze: json['freeze'] == null ? null : asBool(json['freeze']),
        dayExtend: asDouble(json['day_extend']),
        extend: intKeyed(json['extend'], asDouble),
        webhookUrl: asString(json['webhook_url']),
        messages: objects(json['messages'], RentSms.fromJson),
      );

  /// Rent id.
  final int tzid;

  /// `0` reserved, waiting for the first SMS; `1` confirmed (charged).
  final int status;

  /// Number without the country code.
  final String number;

  /// Country code.
  final int country;

  /// Cost incl. extensions, USD (the server sends a number, or a decimal
  /// string in `rent.state`). Reserved while [status] is 0, charged once
  /// confirmed.
  final double sum;

  /// Rent period, days.
  final int days;

  /// Rent period, hours.
  final int hours;

  /// Minutes left.
  final int time;

  /// Seconds left.
  final int? timeSeconds;

  /// Seconds until the rent may be closed.
  final int? guardIntervalRemainingSeconds;

  /// `0` not extendable, `1` extendable, `2` auto-extension.
  final int extension;

  /// Days of auto-extension.
  final int? daysAutoextend;

  /// Start, `YYYY-MM-DD HH:MM:SS`.
  final String startTime;

  /// End, `YYYY-MM-DD HH:MM:SS`.
  final String stopTime;

  /// Last check time.
  final String? checkedTime;

  /// Confirmed.
  final bool? checked;

  /// Frozen.
  final bool? freeze;

  /// Price of one day of extension; `0` when not configured.
  final double? dayExtend;

  /// Days → extension price, USD; `{}` when not extendable.
  final Map<int, double> extend;

  /// Webhook URL of the rent.
  final String? webhookUrl;

  /// SMS, newest first.
  final List<RentSms> messages;
}

/// Rent prices of one country.
final class RentTariff {
  /// Creates a tariff.
  const RentTariff({
    required this.code,
    required this.name,
    required this.enabled,
    required this.isNew,
    required this.position,
    required this.extend,
    required this.days,
    required this.count,
    this.confirm,
    this.extCounts = const {},
  });

  /// Parses a `tariffsRent` country.
  factory RentTariff.fromJson(Map<String, Object?> json) => RentTariff(
        code: asInt(json['code']) ?? 0,
        name: asString(json['name']) ?? '',
        enabled: asBool(json['enabled']),
        isNew: asBool(json['new']),
        position: asInt(json['position']) ?? 0,
        extend: asInt(json['extend']) ?? 0,
        confirm: json['confirm'] == null ? null : asBool(json['confirm']),
        days: intKeyed(json['days'], asDouble),
        count: intKeyed(json['count'], asInt),
        extCounts: intKeyed(json['ext_counts'], asInt),
      );

  /// Country code.
  final int code;

  /// Name (slug).
  final String name;

  /// Enabled for renting.
  final bool enabled;

  /// Marked new (`new` on the wire).
  final bool isNew;

  /// Sort position.
  final int position;

  /// `1` when rents can be extended.
  final int extend;

  /// Needs confirmation.
  final bool? confirm;

  /// Rent days → price, USD.
  final Map<int, double> days;

  /// Rent days → numbers available.
  final Map<int, int> count;

  /// Rent days → numbers available for extension.
  final Map<int, int> extCounts;
}
