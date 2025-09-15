const std = @import("std");
const c = @cImport({
    @cInclude("glib.h");
    @cInclude("gio/gio.h");
    @cInclude("gobject/gobject.h");
});

// -------- TYPES -------- //
pub fn AsyncPayload(comptime T: type) type {
    return struct {
        callback: AsyncResultCallback(T),
        err: [*c][*c]c.GError,
    };
}
pub fn AsyncResultCallback(comptime T: type) type {
    return *const fn (T) callconv(.c) void;
}

pub const LoopControl = extern struct { quit: bool = false };

const file_progress_callback = *fn (c_long, c_long) void;

// -------- ASYNC -------- //
fn ioThread(user_data: ?*anyopaque) callconv(.c) ?*anyopaque {
    const loop_control: *LoopControl = @ptrCast(user_data);
    const context: ?*c.GMainContext = c.g_main_context_new();

    c.g_main_context_push_thread_default(context);

    while (!loop_control.quit) {
        _ = c.g_main_context_iteration(null, 1);
    }

    c.g_main_context_pop_thread_default(context);
    c.g_main_context_unref(context);

    return null;
}

pub export fn init_io_thread() [*c]LoopControl {
    var loop_control = LoopControl{};
    _ = c.g_thread_new("io_thread", ioThread, @ptrCast(&loop_control));
    return &loop_control;
}

pub export fn exit_io_thread(loop_control: *LoopControl) void {
    loop_control.quit = true;
}

// -------- FILE -------- //
pub export fn file_new(path: [*:0]const u8) *c.GFile {
    return c.g_file_new_for_path(path) orelse unreachable;
}

pub export fn file_path(file: *c.GFile) ?[*:0]u8 {
    return c.g_file_get_path(file);
}

pub export fn file_parent(file: *c.GFile) ?*c.GFile {
    return c.g_file_get_parent(file);
}

fn fileDeleteFinish(obj: [*c]c.GObject, result: ?*c.GAsyncResult, user_data: ?*anyopaque) callconv(.c) void {
    const payload: *AsyncPayload(bool) = @ptrCast(@alignCast(user_data));
    const callback = payload.callback;

    const file: *c.GFile = @ptrCast(obj);
    const status = c.g_file_delete_finish(file, result, payload.err);

    callback(status == 1);
    std.heap.c_allocator.destroy(payload);
}

pub export fn file_delete(
    file: *c.GFile,
    cancellable: ?*c.GCancellable,
    result_callback: AsyncResultCallback(bool),
    err: [*c][*c]c.GError,
) void {
    var payload = std.heap.c_allocator.create(AsyncPayload(bool)) catch return;
    payload.callback = result_callback;
    payload.err = err;

    c.g_file_delete_async(
        file,
        c.G_PRIORITY_DEFAULT,
        cancellable,
        fileDeleteFinish,
        @ptrCast(payload),
    );
}

fn fileTrashFinish(obj: [*c]c.GObject, result: ?*c.GAsyncResult, user_data: ?*anyopaque) callconv(.c) void {
    const payload: *AsyncPayload(bool) = @ptrCast(@alignCast(user_data));
    const callback = payload.callback;

    const file: *c.GFile = @ptrCast(obj);
    const status = c.g_file_trash_finish(file, result, payload.err);

    callback(status == 1);
    std.heap.c_allocator.destroy(payload);
}

pub export fn file_trash(
    file: *c.GFile,
    cancellable: ?*c.GCancellable,
    result_callback: AsyncResultCallback(bool),
    err: [*c][*c]c.GError,
) void {
    var payload = std.heap.c_allocator.create(AsyncPayload(bool)) catch return;
    payload.callback = result_callback;
    payload.err = err;

    c.g_file_trash_async(
        file,
        c.G_PRIORITY_DEFAULT,
        cancellable,
        fileTrashFinish,
        @ptrCast(payload),
    );
}

fn fileCreateFinish(obj: [*c]c.GObject, result: ?*c.GAsyncResult, user_data: ?*anyopaque) callconv(.c) void {
    const payload: *AsyncPayload(bool) = @ptrCast(@alignCast(user_data));
    const callback = payload.callback;

    const file: *c.GFile = @ptrCast(obj);
    const out = c.g_file_create_finish(file, result, payload.err);

    if (out) |stream| {
        c.g_object_unref(@ptrCast(stream));
        callback(true);
    } else {
        callback(false);
    }
    std.heap.c_allocator.destroy(payload);
}

pub export fn file_create(
    file: *c.GFile,
    flags: u32,
    cancellable: ?*c.GCancellable,
    result_callback: AsyncResultCallback(bool),
    err: [*c][*c]c.GError,
) void {
    var payload = std.heap.c_allocator.create(AsyncPayload(bool)) catch return;
    payload.callback = result_callback;
    payload.err = err;

    c.g_file_create_async(
        file,
        flags,
        c.G_PRIORITY_DEFAULT,
        cancellable,
        fileCreateFinish,
        @ptrCast(payload),
    );
}

fn fileQueryInfoFinish(obj: [*c]c.GObject, result: ?*c.GAsyncResult, user_data: ?*anyopaque) callconv(.c) void {
    const payload: *AsyncPayload(?*c.GFileInfo) = @ptrCast(@alignCast(user_data));
    const callback = payload.callback;

    const file: *c.GFile = @ptrCast(obj);
    const info = c.g_file_query_info_finish(file, result, payload.err);

    callback(info);
    std.heap.c_allocator.destroy(payload);
}

pub export fn file_query_info(
    file: *c.GFile,
    attributes: [*c]const u8,
    flags: u32,
    cancellable: ?*c.GCancellable,
    result_callback: AsyncResultCallback(?*c.GFileInfo),
    err: [*c][*c]c.GError,
) void {
    var payload = std.heap.c_allocator.create(AsyncPayload(?*c.GFileInfo)) catch return;
    payload.callback = result_callback;
    payload.err = err;

    c.g_file_query_info_async(
        file,
        attributes,
        flags,
        c.G_PRIORITY_DEFAULT,
        cancellable,
        fileQueryInfoFinish,
        @ptrCast(payload),
    );
}

fn fileProgress(current: c_long, total: c_long, user_data: ?*anyopaque) callconv(.c) void {
    if (user_data == null) return;

    const callback: file_progress_callback = @ptrCast(user_data);
    callback(current, total);
}

fn fileCopyFinish(obj: [*c]c.GObject, result: ?*c.GAsyncResult, user_data: ?*anyopaque) callconv(.c) void {
    const payload: *AsyncPayload(bool) = @ptrCast(@alignCast(user_data));
    const callback = payload.callback;

    const file: *c.GFile = @ptrCast(obj);
    const status = c.g_file_copy_finish(file, result, payload.err);

    callback(status == 1);
    std.heap.c_allocator.destroy(payload);
}

pub export fn file_copy(
    src: *c.GFile,
    dst: *c.GFile,
    flags: u32,
    cancellable: ?*c.GCancellable,
    progress_callback: ?file_progress_callback,
    result_callback: AsyncResultCallback(bool),
    err: [*c][*c]c.GError,
) void {
    var payload = std.heap.c_allocator.create(AsyncPayload(bool)) catch return;
    payload.callback = result_callback;
    payload.err = err;

    c.g_file_copy_async(
        src,
        dst,
        flags,
        c.G_PRIORITY_DEFAULT,
        cancellable,
        if (progress_callback != null) fileProgress else null,
        @ptrCast(progress_callback),
        fileCopyFinish,
        @ptrCast(payload),
    );
}

fn fileMoveFinish(obj: [*c]c.GObject, result: ?*c.GAsyncResult, user_data: ?*anyopaque) callconv(.c) void {
    const payload: *AsyncPayload(bool) = @ptrCast(@alignCast(user_data));
    const callback = payload.callback;

    const file: *c.GFile = @ptrCast(obj);
    const status = c.g_file_move_finish(file, result, payload.err);

    callback(status == 1);
    std.heap.c_allocator.destroy(payload);
}

pub export fn file_move(
    src: *c.GFile,
    dst: *c.GFile,
    flags: u32,
    cancellable: ?*c.GCancellable,
    progress_callback: ?file_progress_callback,
    result_callback: AsyncResultCallback(bool),
    err: [*c][*c]c.GError,
) void {
    var payload = std.heap.c_allocator.create(AsyncPayload(bool)) catch return;
    payload.callback = result_callback;
    payload.err = err;

    c.g_file_move_async(
        src,
        dst,
        flags,
        c.G_PRIORITY_DEFAULT,
        cancellable,
        if (progress_callback != null) fileProgress else null,
        @ptrCast(progress_callback),
        fileMoveFinish,
        @ptrCast(payload),
    );
}

fn fileEnumerateChildrenFinish(obj: [*c]c.GObject, result: ?*c.GAsyncResult, user_data: ?*anyopaque) callconv(.c) void {
    const payload: *AsyncPayload(?*c.GFileEnumerator) = @ptrCast(@alignCast(user_data));
    const callback = payload.callback;

    const file: *c.GFile = @ptrCast(obj);
    const enumerator = c.g_file_enumerate_children_finish(file, result, payload.err);

    callback(enumerator);
    std.heap.c_allocator.destroy(payload);
}

pub export fn file_enumerate_children(
    file: *c.GFile,
    attributes: [*c]const u8,
    flags: u32,
    cancellable: ?*c.GCancellable,
    result_callback: AsyncResultCallback(?*c.GFileEnumerator),
    err: [*c][*c]c.GError,
) void {
    var payload = std.heap.c_allocator.create(AsyncPayload(?*c.GFileEnumerator)) catch return;
    payload.callback = result_callback;
    payload.err = err;

    c.g_file_enumerate_children_async(
        file,
        attributes,
        flags,
        c.G_PRIORITY_DEFAULT,
        cancellable,
        fileEnumerateChildrenFinish,
        @ptrCast(payload),
    );
}

// -------- FILE ENUMERATOR -------- //
pub export fn fileenum_is_closed(enumerator: ?*c.GFileEnumerator) bool {
    return c.g_file_enumerator_is_closed(enumerator) == 1;
}

fn fileEnumCloseFinish(obj: [*c]c.GObject, result: ?*c.GAsyncResult, user_data: ?*anyopaque) callconv(.c) void {
    const payload: *AsyncPayload(bool) = @ptrCast(@alignCast(user_data));
    const callback = payload.callback;

    const enumerator: *c.GFileEnumerator = @ptrCast(obj);
    const status = c.g_file_enumerator_close_finish(enumerator, result, payload.err);

    callback(status == 1);
    std.heap.c_allocator.destroy(payload);
}

pub export fn fileenum_close(
    enumerator: *c.GFileEnumerator,
    cancellable: ?*c.GCancellable,
    result_callback: AsyncResultCallback(bool),
    err: [*c][*c]c.GError,
) void {
    var payload = std.heap.c_allocator.create(AsyncPayload(bool)) catch return;
    payload.callback = result_callback;
    payload.err = err;

    c.g_file_enumerator_close_async(
        enumerator,
        c.G_PRIORITY_DEFAULT,
        cancellable,
        fileEnumCloseFinish,
        @ptrCast(payload),
    );
}

fn fileEnumNextFilesFinish(obj: [*c]c.GObject, result: ?*c.GAsyncResult, user_data: ?*anyopaque) callconv(.c) void {
    const payload: *AsyncPayload(?*c.GList) = @ptrCast(@alignCast(user_data));
    const callback = payload.callback;

    const enumerator: *c.GFileEnumerator = @ptrCast(obj);
    const files = c.g_file_enumerator_next_files_finish(enumerator, result, payload.err);

    callback(files);
    std.heap.c_allocator.destroy(payload);
}

pub export fn fileenum_next_files(
    enumerator: *c.GFileEnumerator,
    num_files: c_int,
    cancellable: ?*c.GCancellable,
    result_callback: AsyncResultCallback(?*c.GList),
    err: [*c][*c]c.GError,
) void {
    var payload = std.heap.c_allocator.create(AsyncPayload(?*c.GList)) catch return;
    payload.callback = result_callback;
    payload.err = err;

    c.g_file_enumerator_next_files_async(
        enumerator,
        num_files,
        c.G_PRIORITY_DEFAULT,
        cancellable,
        fileEnumNextFilesFinish,
        @ptrCast(payload),
    );
}

pub export fn fileenum_get_file(enumerator: *c.GFileEnumerator, info: *c.GFileInfo) ?*c.GFile {
    return c.g_file_enumerator_get_child(enumerator, info);
}

// -------- FILE INFO -------- //
pub export fn fileinfo_get_name(info: *c.GFileInfo) [*c]const u8 {
    return c.g_file_info_get_name(info);
}

pub export fn fileinfo_get_file_type(info: *c.GFileInfo) c_uint {
    return c.g_file_info_get_file_type(info);
}

pub export fn fileinfo_get_creation_time(info: *c.GFileInfo) ?[*]const u8 {
    const time = c.g_file_info_get_creation_date_time(info);
    if (time) |_time| {
        const iso_str = c.g_date_time_format_iso8601(_time);
        c.g_date_time_unref(time);
        return iso_str;
    }
    return null;
}

pub export fn fileinfo_get_access_time(info: *c.GFileInfo) ?[*]const u8 {
    const time = c.g_file_info_get_access_date_time(info);
    if (time) |_time| {
        const iso_str = c.g_date_time_format_iso8601(_time);
        c.g_date_time_unref(time);
        return iso_str;
    }
    return null;
}

pub export fn fileinfo_get_modification_time(info: *c.GFileInfo) ?[*]const u8 {
    const time = c.g_file_info_get_modification_date_time(info);
    if (time) |_time| {
        const iso_str = c.g_date_time_format_iso8601(_time);
        c.g_date_time_unref(time);
        return iso_str;
    }
    return null;
}

pub export fn fileinfo_get_size(info: *c.GFileInfo) c_long {
    return c.g_file_info_get_size(info);
}

pub export fn fileinfo_get_is_hidden(info: *c.GFileInfo) bool {
    return c.g_file_info_get_is_hidden(info) == 1;
}

pub export fn fileinfo_list_attributes(info: *c.GFileInfo, namespace: ?[*]u8) [*c][*c]u8 {
    return c.g_file_info_list_attributes(info, namespace);
}

// -------- CANCELLABLE -------- //
fn onCancel(_: [*c]c.GCancellable, user_data: ?*anyopaque) callconv(.c) void {
    const callback: *fn () callconv(.c) void = @ptrCast(user_data);
    callback();
}

pub export fn cancellable_new() ?*c.GCancellable {
    return c.g_cancellable_new();
}

pub export fn cancellable_connect(
    cancellable: *c.GCancellable,
    on_cancel: *const fn () callconv(.c) void,
) c.ulong {
    return c.g_cancellable_connect(
        cancellable,
        c.G_CALLBACK(onCancel),
        @ptrCast(@constCast(on_cancel)),
        null,
    );
}

pub export fn cancellable_cancel(fs_cancellable: *c.GCancellable) void {
    c.g_cancellable_cancel(fs_cancellable);
}

pub export fn cancellable_is_cancelled(fs_cancellable: *c.GCancellable) bool {
    return c.g_cancellable_is_cancelled(fs_cancellable) == 1;
}

pub export fn cancellable_destroy(fs_cancellable: *c.GCancellable, cancel_callback_handler_id: c.ulong) void {
    c.g_cancellable_disconnect(fs_cancellable, cancel_callback_handler_id);
    c.g_object_unref(fs_cancellable);
}

// -------- ERROR -------- //
pub export fn error_new() [*c][*c]c.GError {
    const container = std.heap.c_allocator.create([*c]c.GError) catch return null;
    container.* = null;
    return container;
}

pub export fn error_destroy(err: [*c][*c]c.GError) void {
    if (err.* != null) c.g_error_free(err.*);
}

pub export fn error_domain_name(err: *c.GError) [*c]const u8 {
    return c.g_quark_to_string(err.domain);
}

// -------- LIST -------- //
pub export fn list_destroy(list: [*c]c.GList) void {
    c.g_list_free(list);
}

// -------- MEMORY -------- //
pub export fn obj_unref(obj: ?*anyopaque) void {
    c.g_object_unref(obj);
}
