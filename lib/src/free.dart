import 'client.dart';
import 'json.dart';
import 'models/free.dart';

/// Public free numbers: `client.free`. No key needed.
final class FreeApi {
  /// Internal: the client builds its sections.
  FreeApi(this._request);

  final RequestFn _request;

  /// Countries, the numbers of the selected [country] and the SMS of the
  /// selected [number] (without the country code, as the keys of
  /// [FreeList.numbers]). [page] and [count] page the SMS (count 10–500).
  Future<FreeList> list({
    int? country,
    String? number,
    int? page,
    int? count,
  }) async {
    final res = await _request('getFreeList', query: {
      'country': country,
      'number': number,
      'page': page,
      'count': count,
    });
    return FreeList.fromJson(asMap(res));
  }
}
