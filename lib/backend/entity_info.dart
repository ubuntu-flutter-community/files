/*
Copyright 2019 The dahliaOS Authors

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
*/

import 'package:files/backend/database/model.dart';
import 'package:files/backend/fs.dart' as fs;
import 'package:flutter/foundation.dart';

@immutable
class EntityInfo {
  const EntityInfo(this.file, this.stat, this.entityType);

  final fs.File file;
  final EntityStat stat;
  final EntityType entityType;

  String get path => file.path;

  bool _equals(EntityInfo other) {
    return file.path == other.file.path &&
        stat.accessed == other.stat.accessed &&
        stat.changed == other.stat.changed &&
        stat.mode == other.stat.mode &&
        stat.modified == other.stat.modified &&
        stat.size == other.stat.size &&
        stat.type == other.stat.type &&
        entityType == other.entityType;
  }

  @override
  bool operator ==(Object other) {
    if (other is EntityInfo) {
      return _equals(other);
    }
    return false;
  }

  @override
  int get hashCode => Object.hash(
    file.path,
    stat.accessed,
    stat.changed,
    stat.mode,
    stat.modified,
    stat.size,
    stat.type,
    entityType,
  );
}

extension EntityInfoHelpers on EntityInfo {
  bool get isFile => stat.type == EntityType.file || stat.type == EntityType.link;
  bool get isDirectory => stat.type == EntityType.directory;
}

extension EntityInfoListHelpers on List<EntityInfo> {
  List<EntityInfo> get files => where((e) => e.isFile).toList();
  List<EntityInfo> get directories => where((e) => e.isDirectory).toList();
}
