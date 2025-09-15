import 'package:files/backend/database/model.dart';
import 'package:files/backend/fs.dart' as fs;
import 'package:files/backend/providers.dart';
import 'package:isar_community/isar.dart';

class EntityStatCacheHelper {
  Future<EntityStat> get(String path) async {
    final stat = isar.entityStats.where().pathEqualTo(path).findFirstSync();

    if (stat == null) {
      final file = fs.File.fromPath(path);
      final fetchedStat = EntityStat.fromFileInfo(path, await file.queryInfo().result);
      await set(fetchedStat);
      return fetchedStat;
    }
    return stat;
  }

  Future<void> set(EntityStat entity) => isar.writeTxn(() => isar.entityStats.put(entity));
}
