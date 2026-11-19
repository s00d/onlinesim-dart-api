/// Typed client for the OnlineSim API: SMS numbers, rent, account and free
/// numbers, inbound webhooks, and [MockOnlineSim], an offline fake of the API
/// for tests.
///
/// ```dart
/// import 'package:onlinesim/onlinesim.dart';
///
/// final client = OnlineSim(apiKey: 'your-api-key');
/// final order = await client.numbers.getWithNumber('google', country: 44);
/// final code = await client.numbers.waitCode(order.tzid);
/// ```
library;

export 'src/client.dart' show OnlineSim, defaultBaseUrl, defaultTimeout;
export 'src/errors.dart';
export 'src/free.dart';
export 'src/mock/mock.dart';
export 'src/models/free.dart';
export 'src/models/numbers.dart';
export 'src/models/paginator.dart';
export 'src/models/rent.dart';
export 'src/models/user.dart';
export 'src/numbers.dart';
export 'src/rent.dart';
export 'src/transport.dart';
export 'src/user.dart';
export 'src/webhook.dart';
