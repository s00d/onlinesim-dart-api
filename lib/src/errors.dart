/// Base of every exception thrown by the SDK.
///
/// Sealed: a `switch` over an [OnlineSimException] covers [ApiException]
/// (and its subclass [NoNumberException]), [TransportException] and
/// [WaitTimeoutException], plus the plain base for a malformed webhook body.
sealed class OnlineSimException implements Exception {
  /// Creates an exception with a human-readable [message].
  const OnlineSimException(this.message);

  /// Human-readable description.
  final String message;

  @override
  String toString() => '$runtimeType: $message';
}

/// A webhook body passed to `parseWebhook` is not a JSON object.
final class WebhookFormatException extends OnlineSimException {
  /// Creates the exception.
  const WebhookFormatException(super.message);
}

/// The API answered with an error code in `response`.
base class ApiException extends OnlineSimException {
  /// Creates an exception for [code]. Without a [message] the text comes from
  /// [errorMessages], or is the code itself.
  ApiException(this.code, [String? message])
      : super(message != null && message.isNotEmpty
            ? message
            : errorMessages[code] ?? code);

  /// Raw error code, e.g. `ERROR_WRONG_KEY`.
  final String code;

  @override
  String toString() => '$runtimeType($code): $message';
}

/// No number is available right now (`NO_NUMBER`, `NO_NUMBER_FOR_FORWARD`).
/// Retry later or pick another country.
final class NoNumberException extends ApiException {
  /// Creates the exception for [code].
  NoNumberException(super.code, [super.message]);
}

/// Network failure, request timeout, or a response that is not JSON.
final class TransportException extends OnlineSimException {
  /// Creates the exception.
  const TransportException(super.message, {this.status, this.body = ''});

  /// HTTP status, or `null` when no response arrived (network error, timeout).
  final int? status;

  /// Start of the response body (up to 500 characters), empty when none.
  final String body;
}

/// `waitCode` gave up: no code arrived within its `timeout`.
final class WaitTimeoutException extends OnlineSimException {
  /// Creates the exception.
  const WaitTimeoutException(super.message);
}

/// Fallback messages for error codes the server sends without a `message`.
const Map<String, String> errorMessages = {
  'ACCOUNT_BLOCKED': 'Account is blocked',
  'ERROR_WRONG_KEY': 'Wrong API key',
  'ERROR_NO_KEY': 'API key is missing',
  'ERROR_NO_SERVICE': 'Service is not specified',
  'API_ACCESS_DISABLED': 'API access is disabled in the profile',
  'API_ACCESS_IP': 'API access from this IP is not allowed in the profile',
  'ERROR_NO_TZID': 'tzid is not specified',
  'ERROR_WRONG_TZID': 'Wrong tzid',
  'ERROR_NO_OPERATIONS': 'No operations',
  'NO_NUMBER': 'No numbers available for this service right now',
  'NO_NUMBER_FOR_FORWARD': 'No numbers available for forwarding',
  'NO_COUNTRY': 'Country not found',
  'UNDEFINED_COUNTRY': 'Unknown country',
  'WARNING_LOW_BALANCE': 'Not enough balance',
  'EXCEEDED_CONCURRENT_OPERATIONS':
      'Too many concurrent operations for this account',
  'INTERVAL_CONCURRENT_REQUESTS_ERROR':
      'Too many concurrent requests, try again in a few seconds',
  'TRY_AGAIN_LATER':
      'Temporarily unable to perform the request, try again later',
  'ACCOUNT_IDENTIFICATION_REQUIRED': 'Account identification is required',
  'ERROR_PARAMS': 'Wrong parameters',
  'API_DISABLED': 'API is disabled',
  'NO_COMPLETE_TZID': 'The operation cannot be closed yet',
  'NO_CLOSE_RENT_US': 'US rent numbers cannot be closed early',
  'UNDEFINED_DAYS': 'Unknown rent period',
  'VALIDATION_ERROR': 'Validation failed',
  'TZ_OVER_OK': 'Operation finished without a new code',
  'ERROR_NO_ITEMS': 'Operation failed',
};
