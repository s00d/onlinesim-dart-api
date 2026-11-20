import '../json.dart';
import '../webhook.dart';
import 'paginator.dart';

/// Account balance, USD.
final class Balance {
  /// Creates a balance.
  const Balance({required this.balance, required this.zbalance, this.income});

  /// Parses `getBalance`; `balance` arrives as a decimal string.
  factory Balance.fromJson(Map<String, Object?> json) => Balance(
        balance: asDouble(json['balance']) ?? 0,
        zbalance: asDouble(json['zbalance']) ?? 0,
        income: asDouble(json['income']),
      );

  /// Total balance. Includes [zbalance]:
  /// available = balance − max(zbalance, 0).
  final double balance;

  /// Sum frozen by numbers and unconfirmed rents in progress; may be negative.
  final double zbalance;

  /// Partner income, when sent.
  final double? income;

  /// Spendable part: [balance] − max([zbalance], 0).
  double get available => balance - (zbalance > 0 ? zbalance : 0);
}

/// The account profile.
final class Profile {
  /// Creates a profile.
  const Profile({
    required this.id,
    this.hashId,
    this.name,
    this.username,
    this.email,
    this.emailVerifiedAt,
    this.apikey,
    this.apiAccess,
    this.locale,
    this.currency,
    this.numberCountry,
    this.numberReject = const [],
    this.webhookUrl,
    this.number,
    this.country,
    this.isApi,
    this.createdAt,
  });

  /// Parses `getProfile`'s `profile`.
  factory Profile.fromJson(Map<String, Object?> json) {
    final reject = json['number_reject'];
    return Profile(
      id: asInt(json['id']) ?? 0,
      hashId: asString(json['hash_id']),
      name: asString(json['name']),
      username: asString(json['username']),
      email: asString(json['email']),
      emailVerifiedAt: asString(json['email_verified_at']),
      apikey: asString(json['apikey']),
      apiAccess: json['api_access'],
      locale: asString(json['locale']),
      currency: asString(json['currency']),
      numberCountry: asInt(json['number_country']),
      numberReject: reject is Map
          ? listOf(reject.values.toList(), asString)
          : listOf(reject, asString),
      webhookUrl: asString(json['webhook_url']),
      number: asInt(json['number']),
      country: asString(json['country']),
      isApi: json['is_api'] == null ? null : asBool(json['is_api']),
      createdAt: asString(json['created_at']),
    );
  }

  /// Account id.
  final int id;

  /// Public hash id.
  final String? hashId;

  /// Name.
  final String? name;

  /// Username.
  final String? username;

  /// Email.
  final String? email;

  /// Email verification time.
  final String? emailVerifiedAt;

  /// API key.
  final String? apikey;

  /// `true`, or a map of allowed IPs, as sent.
  final Object? apiAccess;

  /// Language of server texts.
  final String? locale;

  /// Currency.
  final String? currency;

  /// Default country for numbers.
  final int? numberCountry;

  /// Number prefixes skipped by default.
  final List<String> numberReject;

  /// URL that receives SMS webhooks.
  final String? webhookUrl;

  /// Phone number of the account, digits.
  final int? number;

  /// Country of the account.
  final String? country;

  /// API user.
  final bool? isApi;

  /// Registration time.
  final String? createdAt;
}

/// A top-up order.
final class PaymentOrder {
  /// Creates an order.
  const PaymentOrder({
    required this.id,
    required this.sum,
    required this.stat,
    required this.createdAt,
    this.currency,
    this.formText,
    this.statusText,
    this.raw = const {},
  });

  /// Parses an order; [raw] keeps every field as sent.
  factory PaymentOrder.fromJson(Map<String, Object?> json) => PaymentOrder(
        id: asInt(json['id']) ?? 0,
        sum: asString(json['sum']) ?? '',
        currency: asString(json['currency']),
        stat: asInt(json['stat']) ?? 0,
        formText: asString(json['form_text']),
        statusText: asString(json['status_text']),
        createdAt: asString(json['created_at']) ?? '',
        raw: json,
      );

  /// Order id.
  final int id;

  /// Decimal string, e.g. `"89.00"`.
  final String sum;

  /// Currency; `null` when the server sent none.
  final String? currency;

  /// Status code.
  final int stat;

  /// Payment method.
  final String? formText;

  /// Status text.
  final String? statusText;

  /// Creation time.
  final String createdAt;

  /// The order as sent by the server.
  final Map<String, Object?> raw;
}

/// Result of `user.paymentHistory`.
final class PaymentHistory {
  /// Creates a payment history page.
  const PaymentHistory({
    required this.orders,
    this.paylist = const {},
    this.domains = const [],
    this.currency = const {},
  });

  /// Parses `getPaymentHistory`. A `paylist` sent as a JSON array (group ids
  /// 0, 1, 2…) is kept as an index-keyed map (`'0'`, `'1'`, …); `[]` is `{}`.
  factory PaymentHistory.fromJson(Map<String, Object?> json) => PaymentHistory(
        orders:
            Paginator.fromJson(asMap(json['orders']), PaymentOrder.fromJson),
        paylist: switch (json['paylist']) {
          final List<Object?> list => {
              for (var i = 0; i < list.length; i++) '$i': list[i],
            },
          final other => asMap(other),
        },
        domains: listOf(json['domains'], asString),
        currency: stringKeyed(json['currency'], asDouble),
      );

  /// Orders, newest first.
  final Paginator<PaymentOrder> orders;

  /// Payment methods by group id.
  final Map<String, Object?> paylist;

  /// Payment domains.
  final List<String> domains;

  /// Currency → rate.
  final Map<String, double> currency;
}

/// One webhook delivery.
final class WebhookLog {
  /// Creates a log entry.
  const WebhookLog({
    required this.id,
    required this.userId,
    required this.webhookUrl,
    required this.type,
    required this.params,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
    this.error,
  });

  /// Parses a `webhook-logs` item.
  factory WebhookLog.fromJson(Map<String, Object?> json) => WebhookLog(
        id: asInt(json['id']) ?? 0,
        userId: asInt(json['user_id']) ?? 0,
        webhookUrl: asString(json['webhook_url']) ?? '',
        type: WebhookType.parse(json['type']),
        params: WebhookPayload.fromJson(asMap(json['params'])),
        status: asString(json['status']) ?? '',
        error: asString(json['error']),
        createdAt: asString(json['created_at']) ?? '',
        updatedAt: asString(json['updated_at']) ?? '',
      );

  /// Log id.
  final int id;

  /// Account id.
  final int userId;

  /// URL the payload was sent to.
  final String webhookUrl;

  /// Kind of operation; `null` for an unknown one.
  final WebhookType? type;

  /// The payload that was sent.
  final WebhookPayload params;

  /// `success`, `fail` or `pending`.
  final String status;

  /// Delivery error, if any.
  final String? error;

  /// Creation time.
  final String createdAt;

  /// Last update time.
  final String updatedAt;
}
