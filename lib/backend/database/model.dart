import 'package:files/backend/fs.dart' as fs;
import 'package:files/backend/providers.dart';
import 'package:flutter/foundation.dart';
import 'package:isar_community/isar.dart';

part 'model.g.dart';

typedef _FileInfoSnapshot = ({
  DateTime changed,
  DateTime modified,
  DateTime accessed,
  EntityType type,
  int mode,
  int size,
});

_FileInfoSnapshot _getSnapshotForInfo(fs.FileInfo info) {
  final attributes = info.listAttributes()!;

  assert(attributes.contains('standard::type'));
  // assert(attributes.contains('time::modified'));
  // assert(attributes.contains('time::access'));
  // assert(attributes.contains('time::created'));
  assert(attributes.contains('standard::size'));

  final defaultTime = DateTime.fromMillisecondsSinceEpoch(0);

  return (
    changed: info.getCreationTime() ?? defaultTime,
    modified: info.getModificationTime() ?? defaultTime,
    accessed: info.getAccessTime() ?? defaultTime,
    type: switch (info.getFileType()) {
      1 || 4 || 5 => EntityType.file,
      2 || 6 => EntityType.directory,
      3 => EntityType.link,
      final t => throw ArgumentError.value(t),
    },
    mode: 0, // TODO
    size: info.getSize(),
  );
}

@Collection()
class EntityStat with ChangeNotifier {
  EntityStat();

  EntityStat.fastInit({
    required this.path,
    required this.info,
    required this.changed,
    required this.modified,
    required this.accessed,
    required this.type,
    required this.mode,
    required this.size,
  });

  factory EntityStat.fromFileInfo(String path, fs.FileInfo info) {
    final snapshot = _getSnapshotForInfo(info);

    return EntityStat.fastInit(
      path: path,
      info: info,
      changed: snapshot.changed,
      modified: snapshot.modified,
      accessed: snapshot.accessed,
      type: snapshot.type,
      mode: snapshot.mode,
      size: snapshot.size,
    );
  }

  Id? id;

  @Index(unique: true, type: IndexType.hash)
  late String path;

  @Ignore()
  late fs.FileInfo info;

  late DateTime changed;
  late DateTime modified;
  late DateTime accessed;

  @enumerated
  late EntityType type;
  late int mode;
  late int size;

  Future<void> fetchUpdate() async {
    final file = fs.File.fromPath(path);
    final info = await file.queryInfo().result;
    final snapshot = _getSnapshotForInfo(info);

    if (!_infoIdentical(snapshot)) {
      changed = snapshot.changed;
      modified = snapshot.modified;
      accessed = snapshot.accessed;
      type = snapshot.type;
      mode = snapshot.mode;
      size = snapshot.size;
      await helper.set(this);
      notifyListeners();
    }
  }

  bool _infoIdentical(_FileInfoSnapshot other) {
    return changed == other.changed &&
        modified == other.modified &&
        accessed == other.accessed &&
        type == other.type &&
        mode == other.mode &&
        size == other.size;
  }
}

enum EntityType { file, directory, link, notFound }
