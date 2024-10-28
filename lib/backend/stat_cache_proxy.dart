import 'package:files/backend/database/model.dart';
import 'package:files/backend/providers.dart';

class StatCacheProxy {
  StatCacheProxy();
  final Map<String, EntityStat> _runtimeCache = {};

  Future<EntityStat> get(String path) async {
    if (!_runtimeCache.containsKey(path)) {
      final stat = await helper.get(path);
      await stat.fetchUpdate();
      _runtimeCache[path] = stat;
      return stat;
    }

    // TODO(@HrX03): is this correct?
    // ignore: unawaited_futures
    return _runtimeCache[path]!..fetchUpdate();
  }
}
