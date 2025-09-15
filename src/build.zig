const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(
        .{
            .whitelist = &[_]std.Target.Query{
                .{ .os_tag = .linux },
            },
        },
    );
    const optimize = b.standardOptimizeOption(.{});

    const lib = b.addLibrary(.{
        .linkage = .dynamic,
        .name = "fs",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/lib.zig"),
            .target = target,
            .optimize = optimize,
            .link_libc = true,
        }),
    });

    lib.root_module.linkSystemLibrary("gobject-2.0", .{ .needed = true, .use_pkg_config = .yes });
    lib.root_module.linkSystemLibrary("glib-2.0", .{ .needed = true, .use_pkg_config = .yes });
    lib.root_module.linkSystemLibrary("gio-2.0", .{ .needed = true, .use_pkg_config = .yes });

    b.installArtifact(lib);

    const exe = b.addExecutable(.{
        .name = "fs_exe",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/exe.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    exe.root_module.link_libc = true;
    exe.root_module.linkSystemLibrary("gobject-2.0", .{ .needed = true, .use_pkg_config = .yes });
    exe.root_module.linkSystemLibrary("glib-2.0", .{ .needed = true, .use_pkg_config = .yes });
    exe.root_module.linkSystemLibrary("gio-2.0", .{ .needed = true, .use_pkg_config = .yes });

    b.installArtifact(exe);
}
