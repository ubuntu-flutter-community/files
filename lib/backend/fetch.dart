import 'dart:async';

import 'package:files/backend/database/model.dart';
import 'package:files/backend/entity_info.dart';
import 'package:files/backend/fs.dart' as fs;
import 'package:files/backend/utils.dart';
import 'package:flutter/foundation.dart';

enum SortType { name, modified, type, size }

class CancelableFsFetch {
  CancelableFsFetch({
    required this.source,
    required this.onFetched,
    this.onCancel,
    this.ascending = false,
    this.sortType = SortType.name,
    this.showHidden = false,
  });

  final fs.File source;
  final ValueChanged<List<EntityInfo>?> onFetched;
  final VoidCallback? onCancel;
  final bool ascending;
  final SortType sortType;
  final bool showHidden;

  final fs.Cancellable cancellable = fs.Cancellable();
  final Completer<void> _cancellableCompleter = Completer();

  bool get cancelled => cancellable.isCancelled;

  Future<void> startFetch() async {
    if (cancelled) throw CancelledException();

    final enumeratorOp = source.getEnumerator(
      attributes: 'standard::name,standard::type,standard::size,standard::is-hidden,time::*',
    );
    final enumerator = await enumeratorOp.result;

    final directories = <EntityInfo>[];
    final files = <EntityInfo>[];

    while (true) {
      final fs.FileList? fileList;
      try {
        final enumerateOp = enumerator.enumerate(cancellable: cancellable);
        fileList = await enumerateOp.result;
      } on fs.NativeException catch (e) {
        // G_IO_CANCELLED
        if (e.code == 19) {
          _cancellableCompleter.complete();
          return;
        }

        rethrow;
      }

      if (fileList == null) break;

      for (final info in fileList.iterable()) {
        if (!showHidden && info.isHidden()) continue;
        final file = enumerator.getFile(info);
        if (file == null) continue;

        final stat = EntityStat.fromFileInfo(file.path, info);

        switch (stat.type) {
          case EntityType.file:
            files.add(EntityInfo(file, stat, stat.type));
          case EntityType.directory:
            directories.add(EntityInfo(file, stat, stat.type));
          default:
            break;
        }
      }
      fileList.destroy();
    }

    _cancellableCompleter.complete();

    directories.sort((a, b) => _sort(a, b, isDirectory: true)!);
    files.sort((a, b) => _sort(a, b, isDirectory: false)!);

    if (!cancelled) onFetched.call([...directories, ...files]);
  }

  int? _sort(EntityInfo a, EntityInfo b, {bool isDirectory = false}) {
    EntityInfo item1 = a;
    EntityInfo item2 = b;

    if (!ascending) {
      item2 = a;
      item1 = b;
    }

    switch (sortType.index) {
      case 0:
        return Utils.getEntityName(
          item1.path.toLowerCase(),
        ).compareTo(Utils.getEntityName(item2.path.toLowerCase()));
      case 1:
        return item1.stat.modified.compareTo(item2.stat.modified);
      case 2:
        return 0;
      case 3:
        if (isDirectory) {
          return Utils.getEntityName(
            item1.path.toLowerCase(),
          ).compareTo(Utils.getEntityName(item2.path.toLowerCase()));
        } else {
          return item1.stat.size.compareTo(item2.stat.size);
        }
    }

    return null;
  }

  Future<void> cancel() async {
    if (cancellable.isCancelled) return;

    cancellable.cancel();
    return _cancellableCompleter.future;
  }
}

class CancelledException implements Exception {
  @override
  String toString() {
    return "CancelledException: The fetch was cancelled and can't be restored, please create a new instance for fetching.";
  }
}
