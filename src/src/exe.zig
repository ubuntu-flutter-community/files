const std = @import("std");
const lib = @import("lib.zig");

const c = @cImport({
    @cInclude("glib.h");
    @cInclude("gio/gio.h");
    @cInclude("gobject/gobject.h");
});

fn AsyncPayload(comptime T: type) type {
    return struct {
        done: bool = false,
        value: T,
    };
}

fn ioThread(user_data: ?*anyopaque) callconv(.c) ?*anyopaque {
    _ = user_data;
    const context: ?*c.GMainContext = c.g_main_context_new();

    c.g_main_context_push_thread_default(context);

    while (true) {
        _ = c.g_main_context_iteration(null, 1);
    }

    c.g_main_context_pop_thread_default(context);
    c.g_main_context_unref(context);

    return null;
}

const copy_data = struct {
    source: ?*c.GFile,
    destination: ?*c.GFile,
    flags: c.GFileCopyFlags,
    priority: c_int,
    cancellable: [*c]c.GCancellable,
    progress_callback: c.GFileProgressCallback,
    progress_callback_data: ?*anyopaque,
    callback: c.GAsyncReadyCallback,
    user_data: ?*anyopaque,
};

fn copyAsync(user_data: ?*anyopaque) callconv(.c) c_int {
    const data: *copy_data = @ptrCast(@alignCast(user_data));
    c.g_file_copy_async(
        data.source,
        data.destination,
        data.flags,
        data.priority,
        data.cancellable,
        data.progress_callback,
        data.progress_callback_data,
        copyFinish,
        data.user_data,
    );

    return 0;
}

fn copyFinish(obj: [*c]c.GObject, result: ?*c.GAsyncResult, user_data: ?*anyopaque) callconv(.c) void {
    const payload: *AsyncPayload(bool) = @ptrCast(@alignCast(user_data));
    const file: *c.GFile = @ptrCast(obj);
    const info = c.g_file_copy_finish(file, result, null);

    payload.value = info == 1;
    payload.done = true;

    std.debug.print("done\n", .{});

    copyReport(payload);
}

fn copyReport(payload: *AsyncPayload(bool)) callconv(.c) void {
    std.debug.print("{any}\n", .{payload.value});
}

fn copyProgress(value: f32) callconv(.c) void {
    std.debug.print("{d}\n", .{value});
}

fn unmountFinish(obj: [*c]c.GObject, result: ?*c.GAsyncResult, user_data: ?*anyopaque) callconv(.c) void {
    const payload: *lib.LoopControl = @ptrCast(@alignCast(user_data));

    const mount: *c.GMount = @ptrCast(obj);
    var err: ?*c.GError = null;
    const status = c.g_mount_unmount_with_operation_finish(mount, result, &err);

    if (err) |e| {
        const msg = e.message;
        const code = e.code;
        const domain = c.g_quark_to_string(e.domain);

        std.debug.print("{s}, code {d}: {s}\n", .{ domain, code, msg });
    }

    std.debug.print("success: {any}\n", .{status == 1});
    lib.exit_io_thread(payload);
}

fn showProcessesHandler(
    self: *c.GMountOperation,
    message: [*c]const u8,
    processes: [*c]c.GPid,
    choices: [*c][*c]const u8,
    user_data: ?*anyopaque,
) void {
    _ = user_data;

    // std.debug.print("{d}\n", .{@intFromPtr(message)});
    std.debug.print("{d}\n", .{@intFromPtr(processes)});
    std.debug.print("{d}\n", .{@intFromPtr(choices)});

    if (message) |msg| {
        std.debug.print("msg: {s}\n", .{msg});
    }

    var index: u16 = 0;
    while (true) {
        const pid: c.GPid = processes[index];
        if (pid == 0) break;
        std.debug.print("process {d}: {d}\n", .{ index, pid });
        index += 1;
    }

    index = 0;
    while (true) {
        const choice = choices[index];
        if (choice == null) break;
        std.debug.print("choice {d}: {s}\n", .{ index, choice });
        index += 1;
    }

    c.g_mount_operation_reply(self, 0);
}

pub fn main() !void {
    var loop_control = lib.init_io_thread();
    const allocator = std.heap.c_allocator;

    const monitor = c.g_volume_monitor_get();
    const mount_glist = c.g_volume_monitor_get_mounts(monitor);
    var mounts_array = try std.ArrayList(*c.GMount).initCapacity(allocator, 4);

    var item = mount_glist;
    while (item != null) {
        try mounts_array.append(allocator, @ptrCast(item.*.data));
        item = item.*.next;
    }

    const mounts = try mounts_array.toOwnedSlice(allocator);
    for (mounts) |mount| {
        const mount_operation = c.g_mount_operation_new();
        _ = c.g_signal_connect_data(
            mount_operation,
            "show-processes",
            c.G_CALLBACK(showProcessesHandler),
            null,
            null,
            0,
        );
        c.g_mount_unmount_with_operation(
            mount,
            0,
            mount_operation,
            null,
            unmountFinish,
            @ptrCast(&loop_control),
        );
    }

    // lib.exit_io_thread(loop_control);

    // const drive_path: [:0]const u8 = "/media/dnbia/MacOS";
    // const drive = c.g_file_new_for_path(drive_path);

    // const mount_operation = null; //c.g_mount_operation_new();
    // // c.g_mount_operation_set_choice(mount_operation, 1);

    // c.g_file_eject_mountable_with_operation(
    //     drive,
    //     0,
    //     mount_operation,
    //     null,
    //     unmountFinish,
    //     @ptrCast(&loop_control),
    // );

    while (!loop_control.*.quit) {}
}
