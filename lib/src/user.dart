import 'client.dart';
import 'json.dart';
import 'models/paginator.dart';
import 'models/user.dart';

/// The account: `client.user`.
final class UserApi {
  /// Internal: the client builds its sections.
  UserApi(this._request);

  final RequestFn _request;

  /// Balance in USD. `balance` includes the frozen `zbalance`:
  /// available = balance − zbalance ([Balance.available]).
  Future<Balance> balance() async {
    final res = await _request('getBalance.php', query: {'income': 1});
    return Balance.fromJson(asMap(res));
  }

  /// The account profile.
  Future<Profile> profile() async {
    final res = asMap(await _request('getProfile.php'));
    return Profile.fromJson(asMap(res['profile']));
  }

  /// Top-up orders (paginated, newest first) and the payment methods.
  Future<PaymentHistory> paymentHistory({int page = 1}) async {
    final res = await _request('getPaymentHistory.php', query: {'page': page});
    return PaymentHistory.fromJson(asMap(res));
  }

  /// Sets the URL that receives SMS webhooks. Throws
  /// `ApiException('VALIDATION_ERROR')` for an invalid URL.
  Future<void> setWebhookUrl(String url) async {
    await _request('profile.php', body: {
      'profile': {'webhook_url': url},
    });
  }

  /// Removes the webhook URL (also from operations in progress).
  Future<void> clearWebhookUrl() async {
    await _request('profile.php', body: {
      'profile': {'webhook_url': null},
    });
  }

  /// Webhook delivery log, newest first, 10 per page.
  Future<Paginator<WebhookLog>> webhookLogs({int page = 1}) async {
    final res = asMap(await _request('webhook-logs', query: {'page': page}));
    return Paginator.fromJson(asMap(res['data']), WebhookLog.fromJson);
  }
}
