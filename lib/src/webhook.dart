import 'dart:convert';

import 'errors.dart';
import 'json.dart';

/// Kind of an inbound webhook (`webhook_type`).
enum WebhookType {
  /// SMS to a number operation (`receiving_sms`).
  receivingSms('receiving_sms'),

  /// SMS to a rent (`rent_sms`).
  rentSms('rent_sms');

  const WebhookType(this.wire);

  /// Value on the wire.
  final String wire;

  /// The type for a wire value; `null` for anything else.
  static WebhookType? parse(Object? value) {
    for (final t in values) {
      if (t.wire == value) return t;
    }
    return null;
  }
}

/// An inbound webhook body as normalised by [parseWebhook]: missing or
/// malformed fields are `null`.
final class WebhookPayload {
  /// Creates a payload.
  const WebhookPayload({
    this.webhookType,
    this.operationId,
    this.userId,
    this.countryCode,
    this.number,
    this.sender,
    this.message,
    this.code,
    this.timeStart,
    this.timeLeft,
  });

  /// Lenient parse of a decoded webhook object.
  factory WebhookPayload.fromJson(Map<String, Object?> json) => WebhookPayload(
        webhookType: WebhookType.parse(json['webhook_type']),
        operationId: asInt(json['operation_id']),
        userId: asInt(json['user_id']),
        countryCode: asInt(json['country_code']),
        number: asString(json['number']),
        sender: asString(json['sender']),
        message: asString(json['message']),
        code: asString(json['code']),
        timeStart: asString(json['time_start']),
        timeLeft: asInt(json['time_left']),
      );

  /// Kind of operation.
  final WebhookType? webhookType;

  /// `tzid` of the operation or rent.
  final int? operationId;

  /// Account id.
  final int? userId;

  /// Country code of the number.
  final int? countryCode;

  /// The number, e.g. `+79001234567`.
  final String? number;

  /// Sender of the SMS, e.g. `VK`.
  final String? sender;

  /// Full SMS text.
  final String? message;

  /// Code extracted from the SMS.
  final String? code;

  /// Start of the operation.
  final String? timeStart;

  /// Time left.
  final int? timeLeft;
}

/// Parses an inbound webhook body (`receiving_sms` or `rent_sms`) from a JSON
/// string or an already decoded map.
///
/// Lenient: numeric fields may arrive as strings, missing or malformed fields
/// become `null`, unknown fields are dropped. Throws [WebhookFormatException]
/// only when the input is not a JSON object.
WebhookPayload parseWebhook(Object payload) {
  Object? data = payload;
  if (payload is String) {
    try {
      data = jsonDecode(payload);
    } on FormatException {
      throw const WebhookFormatException('Webhook payload is not valid JSON');
    }
  }
  if (data is! Map) {
    throw const WebhookFormatException('Webhook payload is not a JSON object');
  }
  return WebhookPayload.fromJson(data.cast<String, Object?>());
}
