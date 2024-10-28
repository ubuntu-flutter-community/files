import 'dart:io';

import 'package:files/backend/database/model.dart';
import 'package:files/backend/providers.dart';

class EntityStatCacheHelper {
  Future<EntityStat> get(String path) async {
    final stat = isar.entityStats.where().pathEqualTo(path).findFirstSync();

    if (stat == null) {
      final fetchedStat = EntityStat.fromStat(
        path,
        await FileStat.stat(path),
      );
      await set(fetchedStat);
      return fetchedStat;
    }
    return stat;
  }

  Future<void> set(EntityStat entity) async =>
      await isar.writeTxn(() => isar.entityStats.put(entity));
}
