import '../json.dart';

/// States of a number operation ([Operation.response]).
abstract final class OperationStatus {
  /// The number is being assigned.
  static const inPool = 'TZ_INPOOL';

  /// Waiting for an SMS.
  static const numWait = 'TZ_NUM_WAIT';

  /// An SMS arrived.
  static const numAnswer = 'TZ_NUM_ANSWER';

  /// Finished.
  static const overOk = 'TZ_OVER_OK';

  /// Failed.
  static const errorNoItems = 'ERROR_NO_ITEMS';
}

/// Order of `numbers.state` results (`orderby`).
enum SortOrder {
  /// Oldest first.
  asc,

  /// Newest first.
  desc,
}

/// One SMS of an operation, when `msgList` is set.
final class OperationSms {
  /// Creates an SMS entry.
  const OperationSms({required this.service, this.msg, this.text, this.code});

  /// Parses a `{service, msg}` item.
  factory OperationSms.fromJson(Map<String, Object?> json) => OperationSms(
        service: asString(json['service']) ?? '',
        msg: asString(json['msg']),
        text: asString(json['text']),
        code: asString(json['code']),
      );

  /// Service of the SMS.
  final String service;

  /// Code, or the full text without `messageToCode`.
  final String? msg;

  /// Full text, when sent.
  final String? text;

  /// Code, when sent.
  final String? code;
}

/// A number operation (a `getState` item).
final class Operation {
  /// Creates an operation.
  const Operation({
    required this.tzid,
    required this.response,
    this.number,
    this.service,
    this.country,
    this.sum,
    this.time,
    this.form,
    this.webhookUrl,
    this.msg,
    this.msgList,
    this.guardIntervalRemainingSeconds,
  });

  /// Parses a `getState` item.
  factory Operation.fromJson(Map<String, Object?> json) {
    final msg = json['msg'];
    return Operation(
      tzid: asInt(json['tzid']) ?? 0,
      response: asString(json['response']) ?? '',
      number: asString(json['number']),
      service: asString(json['service']),
      country: asInt(json['country']),
      sum: asDouble(json['sum']),
      time: asInt(json['time']),
      form: asString(json['form']),
      webhookUrl: asString(json['webhook_url']),
      msg: msg is String ? msg : null,
      msgList: msg is List ? objects(msg, OperationSms.fromJson) : null,
      guardIntervalRemainingSeconds:
          asInt(json['guard_interval_remaining_seconds']),
    );
  }

  /// Operation id.
  final int tzid;

  /// State, one of [OperationStatus].
  final String response;

  /// Full number with `+`.
  final String? number;

  /// Service slug.
  final String? service;

  /// Country code.
  final int? country;

  /// Price, USD.
  final double? sum;

  /// Seconds left.
  final int? time;

  /// Order form.
  final String? form;

  /// Webhook URL of the operation.
  final String? webhookUrl;

  /// Code (or full text without `messageToCode`) of the current SMS;
  /// `null` until an SMS arrives and when `msgList` is set.
  final String? msg;

  /// All SMS, when requested with `msgList: true` and at least one arrived.
  final List<OperationSms>? msgList;

  /// Seconds until the operation may be closed.
  final int? guardIntervalRemainingSeconds;
}

/// Result of `numbers.getWithNumber`.
final class NumberOrder {
  /// Creates an order.
  const NumberOrder({
    required this.tzid,
    required this.number,
    required this.country,
    required this.time,
    required this.service,
    this.title,
    this.guardIntervalRemainingSeconds,
  });

  /// Parses a `getNum` answer with `number=1`.
  factory NumberOrder.fromJson(Map<String, Object?> json) => NumberOrder(
        tzid: asInt(json['tzid']) ?? 0,
        number: asString(json['number']) ?? '',
        country: asInt(json['country']) ?? 0,
        time: asInt(json['time']) ?? 0,
        service: asString(json['service']) ?? '',
        title: asString(json['title']),
        guardIntervalRemainingSeconds:
            asInt(json['guard_interval_remaining_seconds']),
      );

  /// Operation id.
  final int tzid;

  /// Full number with `+`, e.g. `+447459608320`.
  final String number;

  /// Country code.
  final int country;

  /// Seconds left.
  final int time;

  /// Service slug.
  final String service;

  /// Service display name, when sent.
  final String? title;

  /// Seconds until the operation may be closed, when sent.
  final int? guardIntervalRemainingSeconds;
}

/// One service of a country in `numbers.tariffs`.
final class ServiceStat {
  /// Creates a service entry.
  const ServiceStat({
    required this.count,
    required this.popular,
    required this.code,
    required this.price,
    required this.id,
    required this.service,
    required this.slug,
  });

  /// Parses a `service_<slug>` entry.
  factory ServiceStat.fromJson(Map<String, Object?> json) => ServiceStat(
        count: asInt(json['count']),
        popular: asBool(json['popular']),
        code: asInt(json['code']) ?? 0,
        price: asDouble(json['price']) ?? 0,
        id: asInt(json['id']) ?? 0,
        service: asString(json['service']) ?? '',
        slug: asString(json['slug']) ?? '',
      );

  /// Numbers in stock; `null` when the server reports it as unknown (`"?"`).
  final int? count;

  /// Marked popular.
  final bool popular;

  /// Country code.
  final int code;

  /// Price, USD.
  final double price;

  /// Service id.
  final int id;

  /// Display name.
  final String service;

  /// Service id for `numbers.get` / `numbers.price`.
  final String slug;
}

/// Services, prices and stock of one country.
final class CountryStat {
  /// Creates a country entry.
  const CountryStat({
    required this.name,
    required this.position,
    required this.code,
    required this.isNew,
    required this.enabled,
    required this.services,
    this.localeName,
    this.other,
  });

  /// Parses a `getNumbersStats` country.
  factory CountryStat.fromJson(Map<String, Object?> json) => CountryStat(
        name: asString(json['name']) ?? '',
        localeName: asString(json['locale_name']),
        position: asInt(json['position']) ?? 0,
        code: asInt(json['code']) ?? 0,
        other: json['other'] == false ? null : asDouble(json['other']),
        isNew: asBool(json['new']),
        enabled: asBool(json['enabled']),
        services: stringKeyed(
          json['services'],
          (v) => v is Map ? ServiceStat.fromJson(asMap(v)) : null,
        ),
      );

  /// Name (slug), e.g. `united_kingdom`.
  final String name;

  /// Localised display name.
  final String? localeName;

  /// Sort position.
  final int position;

  /// Country code.
  final int code;

  /// Price of other services; `null` when not set.
  final double? other;

  /// Marked new (`new` on the wire).
  final bool isNew;

  /// Enabled for ordering.
  final bool enabled;

  /// Map `service_<slug>` → service; `{}` when there are none.
  final Map<String, ServiceStat> services;
}
