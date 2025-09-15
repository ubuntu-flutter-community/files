// ignore_for_file: non_constant_identifier_names

@DefaultAsset('package:files/libfs.dart')
library;

import 'dart:ffi';

final class GDirectory extends Opaque {}

final class GFile extends Opaque {}

final class GFileInfo extends Opaque {}

final class GFileEnumerator extends Opaque {}

final class GCancellable extends Opaque {}

final class LoopControl extends Opaque {}

final class GError extends Struct {
  @Uint32()
  external final int quark;

  @Int32()
  external final int code;

  external final Pointer<Char> message;
}

final class GList extends Struct {
  external final Pointer<Void> data;
  external final Pointer<GList> next;
  external final Pointer<GList> previous;
}

@Native<Void Function(Pointer<Void>)>()
external void obj_unref(Pointer<Void> obj);

@Native<Pointer<GCancellable> Function()>()
external Pointer<GCancellable> cancellable_new();

@Native<UnsignedLong Function(Pointer<GCancellable>, Pointer<NativeFunction<Void Function()>>)>()
external int cancellable_connect(
  Pointer<GCancellable> cancellable,
  Pointer<NativeFunction<Void Function()>> onCancel,
);

@Native<Void Function(Pointer<GCancellable>)>()
external void cancellable_cancel(Pointer<GCancellable> cancellable);

@Native<Bool Function(Pointer<GCancellable>)>()
external bool cancellable_is_cancelled(Pointer<GCancellable> cancellable);

@Native<Void Function(Pointer<GCancellable>, UnsignedLong)>()
external void cancellable_destroy(Pointer<GCancellable> cancellable, int cancelCallbackHandlerId);

@Native<Pointer<Pointer<GError>> Function()>()
external Pointer<Pointer<GError>> error_new();

@Native<Void Function(Pointer<Pointer<GError>>)>()
external void error_destroy(Pointer<Pointer<GError>> error);

@Native<Pointer<Char> Function(Pointer<GError>)>()
external Pointer<Char> error_domain_name(Pointer<GError> error);

@Native<Void Function(Pointer<GList>)>()
external void list_destroy(Pointer<GList> list);

@Native<Pointer<LoopControl> Function()>()
external Pointer<LoopControl> init_io_thread();

@Native<Void Function(Pointer<LoopControl>)>()
external void exit_io_thread(Pointer<LoopControl> loopControl);

@Native<Pointer<GDirectory> Function(Pointer<Char>)>()
external Pointer<GDirectory> dir_open(Pointer<Char> path);

@Native<Pointer<Char> Function(Pointer<GDirectory>)>()
external Pointer<Char> dir_read_entry(Pointer<GDirectory> dir);

@Native<Void Function(Pointer<GDirectory>)>()
external void dir_close(Pointer<GDirectory> dir);

@Native<Pointer<GFile> Function(Pointer<Char>)>()
external Pointer<GFile> file_new(Pointer<Char> path);

@Native<Pointer<Char> Function(Pointer<GFile>)>()
external Pointer<Char> file_path(Pointer<GFile> file);

@Native<Pointer<GFile> Function(Pointer<GFile>)>()
external Pointer<GFile> file_parent(Pointer<GFile> file);

@Native<
  Void Function(
    Pointer<GFile>,
    Pointer<GCancellable>,
    Pointer<NativeFunction<Void Function(Bool)>>,
    Pointer<Pointer<GError>>,
  )
>()
external void file_delete(
  Pointer<GFile> file,
  Pointer<GCancellable> cancellable,
  Pointer<NativeFunction<Void Function(Bool)>> resultCallback,
  Pointer<Pointer<GError>> error,
);

@Native<
  Void Function(
    Pointer<GFile>,
    Pointer<GCancellable>,
    Pointer<NativeFunction<Void Function(Bool)>>,
    Pointer<Pointer<GError>>,
  )
>()
external void file_trash(
  Pointer<GFile> file,
  Pointer<GCancellable> cancellable,
  Pointer<NativeFunction<Void Function(Bool)>> resultCallback,
  Pointer<Pointer<GError>> error,
);

@Native<
  Void Function(
    Pointer<GFile>,
    Uint32,
    Pointer<GCancellable>,
    Pointer<NativeFunction<Void Function(Bool)>>,
    Pointer<Pointer<GError>>,
  )
>()
external void file_create(
  Pointer<GFile> file,
  int flags,
  Pointer<GCancellable> cancellable,
  Pointer<NativeFunction<Void Function(Bool)>> resultCallback,
  Pointer<Pointer<GError>> error,
);

@Native<
  Void Function(
    Pointer<GFile>,
    Pointer<Char>,
    Uint32,
    Pointer<GCancellable>,
    Pointer<NativeFunction<Void Function(Pointer<GFileInfo>)>>,
    Pointer<Pointer<GError>>,
  )
>()
external void file_query_info(
  Pointer<GFile> file,
  Pointer<Char> attributes,
  int flags,
  Pointer<GCancellable> cancellable,
  Pointer<NativeFunction<Void Function(Pointer<GFileInfo>)>> resultCallback,
  Pointer<Pointer<GError>> error,
);

@Native<
  Void Function(
    Pointer<GFile>,
    Pointer<GFile>,
    Uint32,
    Pointer<GCancellable>,
    Pointer<NativeFunction<Void Function(Long, Long)>>,
    Pointer<NativeFunction<Void Function(Bool)>>,
    Pointer<Pointer<GError>>,
  )
>()
external void file_copy(
  Pointer<GFile> src,
  Pointer<GFile> dst,
  int flags,
  Pointer<GCancellable> cancellable,
  Pointer<NativeFunction<Void Function(Long, Long)>> progressCallback,
  Pointer<NativeFunction<Void Function(Bool)>> resultCallback,
  Pointer<Pointer<GError>> error,
);

@Native<
  Bool Function(
    Pointer<GFile>,
    Pointer<GFile>,
    Uint32,
    Pointer<GCancellable>,
    Pointer<NativeFunction<Void Function(Long, Long)>>,
    Pointer<NativeFunction<Void Function(Bool)>>,
    Pointer<Pointer<GError>>,
  )
>()
external bool file_move(
  Pointer<GFile> src,
  Pointer<GFile> dst,
  int flags,
  Pointer<GCancellable> cancellable,
  Pointer<NativeFunction<Void Function(Long, Long)>> progressCallback,
  Pointer<NativeFunction<Void Function(Bool)>> resultCallback,
  Pointer<Pointer<GError>> error,
);

@Native<
  Void Function(
    Pointer<GFile>,
    Pointer<Char>,
    Uint32,
    Pointer<GCancellable>,
    Pointer<NativeFunction<Void Function(Pointer<GFileEnumerator>)>>,
    Pointer<Pointer<GError>>,
  )
>()
external void file_enumerate_children(
  Pointer<GFile> file,
  Pointer<Char> attributes,
  int flags,
  Pointer<GCancellable> cancellable,
  Pointer<NativeFunction<Void Function(Pointer<GFileEnumerator>)>> resultCallback,
  Pointer<Pointer<GError>> error,
);

// File enumerator
@Native<Bool Function(Pointer<GFileEnumerator>)>()
external bool fileenum_is_closed(Pointer<GFileEnumerator> enumerator);

@Native<
  Void Function(
    Pointer<GFileEnumerator>,
    Pointer<GCancellable>,
    Pointer<NativeFunction<Void Function(Pointer<GList>)>>,
    Pointer<Pointer<GError>>,
  )
>()
external void fileenum_close(
  Pointer<GFileEnumerator> enumerator,
  Pointer<GCancellable> cancellable,
  Pointer<NativeFunction<Void Function(Pointer<GList>)>> resultCallback,
  Pointer<Pointer<GError>> error,
);

@Native<
  Void Function(
    Pointer<GFileEnumerator>,
    Uint32,
    Pointer<GCancellable>,
    Pointer<NativeFunction<Void Function(Pointer<GList>)>>,
    Pointer<Pointer<GError>>,
  )
>()
external void fileenum_next_files(
  Pointer<GFileEnumerator> enumerator,
  int numFiles,
  Pointer<GCancellable> cancellable,
  Pointer<NativeFunction<Void Function(Pointer<GList>)>> resultCallback,
  Pointer<Pointer<GError>> error,
);

@Native<Pointer<GFile> Function(Pointer<GFileEnumerator>, Pointer<GFileInfo>)>()
external Pointer<GFile> fileenum_get_file(
  Pointer<GFileEnumerator> enumerator,
  Pointer<GFileInfo> info,
);

// File info
@Native<Pointer<Char> Function(Pointer<GFileInfo>)>()
external Pointer<Char> fileinfo_get_name(Pointer<GFileInfo> info);

@Native<UnsignedInt Function(Pointer<GFileInfo>)>()
external int fileinfo_get_file_type(Pointer<GFileInfo> info);

@Native<Pointer<Char> Function(Pointer<GFileInfo>)>()
external Pointer<Char> fileinfo_get_creation_time(Pointer<GFileInfo> info);

@Native<Pointer<Char> Function(Pointer<GFileInfo>)>()
external Pointer<Char> fileinfo_get_access_time(Pointer<GFileInfo> info);

@Native<Pointer<Char> Function(Pointer<GFileInfo>)>()
external Pointer<Char> fileinfo_get_modification_time(Pointer<GFileInfo> info);

@Native<Long Function(Pointer<GFileInfo>)>()
external int fileinfo_get_size(Pointer<GFileInfo> info);

@Native<Bool Function(Pointer<GFileInfo>)>()
external bool fileinfo_get_is_hidden(Pointer<GFileInfo> info);

@Native<Pointer<Pointer<Char>> Function(Pointer<GFileInfo>, Pointer<Char>)>()
external Pointer<Pointer<Char>> fileinfo_list_attributes(
  Pointer<GFileInfo> info,
  Pointer<Char> namespace,
);
