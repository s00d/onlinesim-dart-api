// Order a number and wait for its SMS code.
//
// Runs offline against the built-in MockOnlineSim by default. With
// ONLINESIM_KEY set (dart run example/main.dart) it uses the real API — that
// orders a real number and spends money.
import 'dart:io';

import 'package:onlinesim/onlinesim.dart';

Future<void> main() async {
  final key = Platform.environment['ONLINESIM_KEY'];
  final mock = key == null ? MockOnlineSim(balance: 5) : null;
  final client = mock?.client() ?? OnlineSim(apiKey: key);

  try {
    final balance = await client.user.balance();
    print('available: ${balance.available} USD');

    final order = await client.numbers.getWithNumber('google', country: 44);
    print('enter ${order.number} in the app');
    mock?.addSmsAfter(order.tzid, 'Your Google code: 123-456', 1);

    final code = await client.numbers.waitCode(
      order.tzid,
      interval: mock == null ? const Duration(seconds: 5) : Duration.zero,
    );
    print('code: $code');
  } on NoNumberException {
    print('no numbers right now, try another country');
  } on ApiException catch (e) {
    print('API error ${e.code}: ${e.message}');
  } on TransportException catch (e) {
    print('network: ${e.message}');
  } finally {
    client.close();
  }
}
