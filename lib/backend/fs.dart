// ignore_for_file: unnecessary_lambdas

import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:files/backend/fs_native.dart';
import 'package:flutter/foundation.dart';

void initFileSystemThread() {
  // TODO: handle pointer management
  init_io_thread();
}

enum OperationStatus { pending, running, cancellationPending, cancelled, error, complete }

class Cancellable extends ChangeNotifier {
  Cancellable() {
    _cancelCallable = NativeCallable<Void Function()>.isolateLocal(notifyListeners);
    _handle = cancellable_new();
    _cancelCallbackHandlerId = cancellable_connect(_handle, _cancelCallable.nativeFunction);
  }

  late final Pointer<GCancellable> _handle;
  late final NativeCallable<Void Function()> _cancelCallable;
  late final int _cancelCallbackHandlerId;

  bool get isCancelled => cancellable_is_cancelled(_handle);

  void cancel() {
    cancellable_cancel(_handle);
  }

  void destroy() {
    cancellable_destroy(_handle, _cancelCallbackHandlerId);
    _cancelCallable.close();
  }
}

abstract class BaseFileSystemOperation<Res> {
  BaseFileSystemOperation({Cancellable? cancellable}) {
    _implicitCancellable = cancellable == null;
    if (!_implicitCancellable) {
      _cancellable = cancellable!;
    }

    _create();
    _start();
  }

  final ValueNotifier<OperationStatus> _status = ValueNotifier(OperationStatus.pending);
  final Completer<Res> _completer = Completer();
  late final Cancellable _cancellable;
  late final bool _implicitCancellable;
  late final Pointer<Pointer<GError>> _error;

  Future<Res> get result => _completer.future;
  ValueListenable<OperationStatus> get status => _status;
  bool get isCancelled => _cancellable.isCancelled;

  void _start();

  void cancel() => _cancellable.cancel();

  NativeException? _getException() {
    if (_error.value == nullptr) return null;

    final domain = error_domain_name(_error.value).cast<Utf8>().toDartString();
    final message = _error.value.ref.message.cast<Utf8>().toDartString();

    return NativeException._(domain: domain, code: _error.value.ref.code, message: message);
  }

  void _create() {
    if (_implicitCancellable) {
      _cancellable = Cancellable();
    }
    _cancellable.addListener(_onCancel);
    _error = error_new();
  }

  void _destroy() {
    if (_implicitCancellable) {
      _cancellable.destroy();
    }
    error_destroy(_error);
    calloc.free(_error);
  }

  void _onComplete(Res result) {
    final exception = _getException();

    if (exception == null) {
      _status.value = OperationStatus.complete;
      _completer.complete(result);
    } else {
      _status.value =
          exception.code ==
              19 // G_IO_ERROR_CANCELLED
          ? OperationStatus.cancelled
          : OperationStatus.error;
      _completer.completeError(exception);
    }

    _destroy();
  }

  void _onCancel() {
    _status.value = OperationStatus.cancellationPending;
  }
}

typedef _CallableCreateCallback<T> = NativeCallable Function(void Function(T) onComplete);
typedef _StartOperationCallback =
    void Function(
      Pointer<GCancellable> cancellable,
      Pointer<NativeFunction> onComplete,
      Pointer<Pointer<GError>> error,
    );

class FileSystemOperation<Res> extends BaseFileSystemOperation<Res> {
  FileSystemOperation._({
    required this.target,
    required _CallableCreateCallback<Res> onCreateCompleteCallable,
    required _StartOperationCallback onStartOperation,
    super.cancellable,
  }) : _onCreateCompleteCallable = onCreateCompleteCallable,
       _onStartOperation = onStartOperation,
       super();

  final Pointer target;
  final _CallableCreateCallback<Res> _onCreateCompleteCallable;
  final _StartOperationCallback _onStartOperation;

  late final NativeCallable _completeCallable;

  @override
  void _start() {
    _onStartOperation(_cancellable._handle, _completeCallable.nativeFunction, _error);
  }

  @override
  void _create() {
    super._create();
    _completeCallable = _onCreateCompleteCallable(_onComplete);
  }

  @override
  void _destroy() {
    _completeCallable.close();
    super._destroy();
  }
}

class TransferFileOperation extends BaseFileSystemOperation<bool> {
  TransferFileOperation._({
    required this.source,
    required this.destination,
    this.copy = false,
    this.allowOverwrite = false,
    super.cancellable,
  });

  final File source;
  final File destination;
  final bool copy;
  final bool allowOverwrite;

  late final NativeCallable<Void Function(Bool)> _completeCallable;
  late final NativeCallable<Void Function(Long, Long)> _progressCallable;
  final ValueNotifier<(int, int)> _progress = ValueNotifier((0, 0));

  ValueListenable<(int currentBytes, int totalBytes)> get progress => _progress;

  @override
  void _start() {
    if (copy) {
      file_copy(
        source._handle,
        destination._handle,
        allowOverwrite ? 1 : 0,
        _cancellable._handle,
        _progressCallable.nativeFunction,
        _completeCallable.nativeFunction,
        _error,
      );
    } else {
      file_move(
        source._handle,
        destination._handle,
        allowOverwrite ? 1 : 0,
        _cancellable._handle,
        _progressCallable.nativeFunction,
        _completeCallable.nativeFunction,
        _error,
      );
    }
  }

  @override
  void _create() {
    super._create();
    _progressCallable = NativeCallable<Void Function(Long, Long)>.listener(_onProgress);
    _completeCallable = NativeCallable<Void Function(Bool)>.listener(_onComplete);
  }

  @override
  void _destroy() {
    _completeCallable.close();
    _progressCallable.close();
    super._destroy();
  }

  void _onProgress(int current, int total) {
    _progress.value = (current, total);
  }
}

final NativeFinalizer _finalizer = NativeFinalizer(Native.addressOf(obj_unref));

class File implements Finalizable {
  File._(this._handle) {
    _finalizer.attach(this, _handle.cast());
  }

  static File fromRawPath(Pointer<Char> path) {
    final res = file_new(path);

    return File._(res);
  }

  static File fromPath(String path) {
    return using((arena) {
      final pathAlloc = path.toNativeUtf8(allocator: arena);
      final res = file_new(pathAlloc.cast());

      return File._(res);
    });
  }

  final Pointer<GFile> _handle;

  String get path => file_path(_handle).cast<Utf8>().toDartString();
  File? get parent {
    final parent = file_parent(_handle);
    if (parent == nullptr) return null;
    return File._(parent);
  }

  FileSystemOperation<bool> create() {
    return FileSystemOperation<bool>._(
      target: _handle.cast(),
      onCreateCompleteCallable: (onComplete) =>
          NativeCallable<Void Function(Bool)>.listener(onComplete),
      onStartOperation: (cancellable, onComplete, error) =>
          file_create(_handle, 0, cancellable, onComplete.cast(), error),
    );
  }

  TransferFileOperation copy({
    required File destination,
    bool allowOverwrite = false,
    Cancellable? cancellable,
  }) {
    return TransferFileOperation._(
      source: this,
      destination: destination,
      copy: true,
      allowOverwrite: allowOverwrite,
      cancellable: cancellable,
    );
  }

  FileSystemOperation<bool> delete({Cancellable? cancellable}) {
    return FileSystemOperation<bool>._(
      target: _handle.cast(),
      onCreateCompleteCallable: NativeCallable<Void Function(Bool)>.listener,
      onStartOperation: (cancellable, onComplete, error) =>
          file_delete(_handle, cancellable, onComplete.cast(), error),
      cancellable: cancellable,
    );
  }

  FileSystemOperation<FileEnumerator> getEnumerator({
    String attributes = '*',
    Cancellable? cancellable,
  }) {
    return FileSystemOperation<FileEnumerator>._(
      target: _handle.cast(),
      onCreateCompleteCallable: (onComplete) =>
          NativeCallable<Void Function(Pointer<GFileEnumerator>)>.listener(
            (Pointer<GFileEnumerator> v) => onComplete(FileEnumerator._(v)),
          ),
      onStartOperation: (cancellable, onComplete, error) => file_enumerate_children(
        _handle,
        attributes.toNativeUtf8().cast(),
        0,
        cancellable,
        onComplete.cast(),
        error,
      ),
      cancellable: cancellable,
    );
  }

  TransferFileOperation move({
    required File destination,
    bool allowOverwrite = false,
    Cancellable? cancellable,
  }) {
    return TransferFileOperation._(
      source: this,
      destination: destination,
      copy: false,
      allowOverwrite: false,
      cancellable: cancellable,
    );
  }

  FileSystemOperation<FileInfo> queryInfo({String attributes = '*', Cancellable? cancellable}) {
    return FileSystemOperation<FileInfo>._(
      target: _handle.cast(),
      onCreateCompleteCallable: (onComplete) =>
          NativeCallable<Void Function(Pointer<GFileInfo>)>.listener(
            (Pointer<GFileInfo> v) => onComplete(FileInfo._(v)),
          ),
      onStartOperation: (cancellable, onComplete, error) => file_query_info(
        _handle,
        attributes.toNativeUtf8().cast(),
        0,
        cancellable,
        onComplete.cast(),
        error,
      ),
      cancellable: cancellable,
    );
  }

  FileSystemOperation<bool> trash({Cancellable? cancellable}) {
    return FileSystemOperation<bool>._(
      target: _handle.cast(),
      onCreateCompleteCallable: (onComplete) =>
          NativeCallable<Void Function(Bool)>.listener(onComplete),
      onStartOperation: (cancellable, onComplete, error) =>
          file_trash(_handle, cancellable, onComplete.cast(), error),
      cancellable: cancellable,
    );
  }
}

class FileInfo implements Finalizable {
  FileInfo._(this._handle) {
    _finalizer.attach(this, _handle.cast());
  }

  final Pointer<GFileInfo> _handle;
  String? getName() {
    final name = fileinfo_get_name(_handle);
    if (name == nullptr) return null;

    return name.cast<Utf8>().toDartString();
  }

  int getFileType() => fileinfo_get_file_type(_handle);

  DateTime? getCreationTime() {
    final time = fileinfo_get_creation_time(_handle);
    if (time == nullptr) return null;

    try {
      final timeStr = time.cast<Utf8>().toDartString();
      return DateTime.parse(timeStr);
    } finally {
      calloc.free(time);
    }
  }

  DateTime? getAccessTime() {
    final time = fileinfo_get_access_time(_handle);
    if (time == nullptr) return null;

    try {
      final timeStr = time.cast<Utf8>().toDartString();
      return DateTime.parse(timeStr);
    } finally {
      calloc.free(time);
    }
  }

  DateTime? getModificationTime() {
    final time = fileinfo_get_modification_time(_handle);
    if (time == nullptr) return null;

    try {
      final timeStr = time.cast<Utf8>().toDartString();
      return DateTime.parse(timeStr);
    } finally {
      calloc.free(time);
    }
  }

  int getSize() => fileinfo_get_size(_handle);

  bool isHidden() => fileinfo_get_is_hidden(_handle);

  List<String>? listAttributes({String? namespace}) {
    final namespacePtr = namespace?.toNativeUtf8();
    final attributes = fileinfo_list_attributes(_handle, namespacePtr?.cast() ?? nullptr);

    if (namespacePtr != null) calloc.free(namespacePtr);
    if (attributes == nullptr) return null;

    final attributeList = <String>[];
    int index = 0;
    while (true) {
      final attribute = attributes[index];
      if (attribute == nullptr) break;
      attributeList.add(attribute.cast<Utf8>().toDartString());
      calloc.free(attribute);
      index++;
    }
    calloc.free(attributes);

    return attributeList;
  }
}

extension type FileList._(Pointer<GList> _handle) {
  Iterable<FileInfo> iterable() sync* {
    var l = _handle;
    while (l != nullptr) {
      yield FileInfo._(l.ref.data.cast());
      l = l.ref.next;
    }
  }

  void destroy() => list_destroy(_handle);
}

extension type FileEnumerator._(Pointer<GFileEnumerator> _handle) {
  FileSystemOperation<FileList?> enumerate({int fileAmount = 4, Cancellable? cancellable}) {
    return FileSystemOperation<FileList?>._(
      target: _handle.cast(),
      onCreateCompleteCallable: (onComplete) =>
          NativeCallable<Void Function(Pointer<GList>)>.listener(
            (Pointer<GList> v) => onComplete(v != nullptr ? FileList._(v) : null),
          ),
      onStartOperation: (cancellable, onComplete, error) =>
          fileenum_next_files(_handle, fileAmount, cancellable, onComplete.cast(), error),
      cancellable: cancellable,
    );
  }

  FileSystemOperation<bool> close({Cancellable? cancellable}) {
    return FileSystemOperation<bool>._(
      target: _handle.cast(),
      onCreateCompleteCallable: (onComplete) =>
          NativeCallable<Void Function(Bool)>.listener(onComplete),
      onStartOperation: (cancellable, onComplete, error) =>
          fileenum_close(_handle, cancellable, onComplete.cast(), error),
      cancellable: cancellable,
    );
  }

  File? getFile(FileInfo info) {
    final ptr = fileenum_get_file(_handle, info._handle);
    if (ptr == nullptr) return null;
    return File._(ptr);
  }
}

class NativeException implements Exception {
  final String domain;
  final int code;
  final String message;

  const NativeException._({required this.domain, required this.code, required this.message});

  @override
  String toString() {
    return '$domain, code $code: $message';
  }
}
