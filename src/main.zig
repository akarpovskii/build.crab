const std = @import("std");

fn printUsage(io: std.Io) !void {
    var stdout_writer = std.Io.File.stdout().writer(io, &.{});
    const stdout = &stdout_writer.interface;
    try stdout.writeAll(
        "Usage: build_crab " ++
            "--manifest-path <path/to/Cargo.toml> " ++
            "--target-dir <directory> " ++
            "[--deps <.d file path>] " ++
            "[--command <build (default) / rustc / zigbuild etc>] " ++
            "[-- <cargo <command> args>]\n",
    );
}

const CargoMessage = struct {
    reason: []const u8,
    filenames: ?[][]const u8 = null,
    manifest_path: ?[]const u8 = null,
    target: ?CargoTarget = null,
};

const CargoTarget = struct {
    kind: [][]const u8,
};

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const allocator = init.gpa;

    var command: ?[]const u8 = null;
    var deps_file: ?[]const u8 = null;
    var target_dir: ?[]const u8 = null;
    var manifest_path: ?[]const u8 = null;
    var cargo_args: std.ArrayList([]const u8) = .empty;
    defer cargo_args.deinit(allocator);

    var args = try init.minimal.args.iterateAllocator(allocator);
    defer args.deinit();
    _ = args.next();
    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "--command")) {
            command = args.next() orelse break;
        }
        if (std.mem.eql(u8, arg, "--target-dir")) {
            target_dir = args.next() orelse break;
        }
        if (std.mem.eql(u8, arg, "--manifest-path")) {
            manifest_path = args.next() orelse break;
        }
        if (std.mem.eql(u8, arg, "--deps")) {
            deps_file = args.next() orelse break;
        }
        if (std.mem.eql(u8, arg, "--")) {
            while (args.next()) |cargo_arg| {
                try cargo_args.append(allocator, cargo_arg);
            }
            break;
        }
    }

    std.log.debug("Received:", .{});
    std.log.debug("target-dir = {?s}", .{target_dir});
    std.log.debug("manifest-path = {?s}", .{manifest_path});
    std.log.debug("deps = {?s}", .{deps_file});
    std.log.debug("cargo args = {f}", .{std.json.fmt(cargo_args.items, .{})});

    if (target_dir == null or manifest_path == null) {
        try printUsage(io);
        return;
    }

    var cargo_cmd: std.ArrayList([]const u8) = .empty;
    defer cargo_cmd.deinit(allocator);
    try cargo_cmd.append(allocator, "cargo");
    try cargo_cmd.append(allocator, command orelse "build");
    try cargo_cmd.append(allocator, "--message-format=json-render-diagnostics");
    try cargo_cmd.append(allocator, "--target-dir");
    try cargo_cmd.append(allocator, target_dir.?);
    try cargo_cmd.append(allocator, "--manifest-path");
    try cargo_cmd.append(allocator, manifest_path.?);
    for (cargo_args.items) |arg| {
        if (std.mem.containsAtLeast(u8, arg, 1, "--message-format")) {
            continue;
        }
        try cargo_cmd.append(allocator, arg);
    }

    std.log.debug("about to execute {f}", .{std.json.fmt(cargo_cmd.items, .{})});
    const cargo_result = try std.process.run(allocator, io, .{
        .argv = cargo_cmd.items,
    });
    defer {
        allocator.free(cargo_result.stdout);
        allocator.free(cargo_result.stderr);
    }

    var stderr_writer = std.Io.File.stderr().writer(io, &.{});
    const stderr = &stderr_writer.interface;
    try stderr.writeAll(cargo_result.stderr);
    std.log.debug("cargo exit status {any}", .{cargo_result.term});
    switch (cargo_result.term) {
        .exited => |exit_code| if (exit_code != 0) std.process.exit(1),
        else => std.process.exit(1),
    }

    var lines = std.mem.tokenizeScalar(u8, cargo_result.stdout, '\n');
    outer: while (lines.next()) |line| {
        std.log.debug("parsing cargo output: {s}", .{line});
        const parsed_message = try std.json.parseFromSlice(CargoMessage, allocator, line, .{ .ignore_unknown_fields = true });
        defer parsed_message.deinit();
        const message = parsed_message.value;
        if (!std.mem.eql(u8, message.reason, "compiler-artifact")) {
            std.log.debug("not a compiler-artifact, ignored", .{});
            continue;
        }

        const artifact_manifest = message.manifest_path orelse @panic("expected 'manifest_path' to contain a path to artifact's Cargo.toml");
        if (!std.mem.eql(u8, artifact_manifest, manifest_path.?)) {
            std.log.debug("artifact's manifest-path [{s}] does not equal to package's manifest-path, ignored", .{artifact_manifest});
            continue;
        }

        for (message.target.?.kind) |kind| {
            if (std.mem.eql(u8, kind, "custom-build")) {
                std.log.debug("artifact is a custom build script, ignored", .{});
                continue :outer;
            }
        }

        const filenames = message.filenames orelse @panic("expected 'compiler-artifact' to contains a list of filenames");

        if (filenames.len == 0) {
            @panic(try std.fmt.allocPrint(allocator, "no filenames provided by Cargo", .{}));
        }

        const cwd = std.Io.Dir.cwd();
        const dst_dir = try cwd.openDir(io, target_dir.?, .{});
        for (filenames) |artifact| {
            const basename = std.fs.path.basename(artifact);
            std.log.debug("About to copy '{s}' to '{s}/{s}'", .{ artifact, target_dir.?, basename });
            try std.Io.Dir.copyFile(cwd, artifact, dst_dir, basename, io, .{});
        }

        if (deps_file) |deps_path| {
            const artifact = filenames[0];
            const dirname = std.fs.path.dirname(artifact) orelse @panic("dirname cannot be null");
            const stem = std.fs.path.stem(artifact);

            const without_extension = std.fs.path.join(allocator, &.{ dirname, stem }) catch @panic("OOM");
            defer allocator.free(without_extension);
            const artifact_d = try std.mem.concat(allocator, u8, &.{ without_extension, ".d" });
            defer allocator.free(artifact_d);

            std.log.debug("About to copy '{s}' to '{s}'", .{ artifact_d, deps_path });

            const dst = cwd.openFile(io, deps_path, .{ .mode = .read_write }) catch |e| switch (e) {
                error.FileNotFound => try cwd.createFile(io, deps_path, .{ .read = true }),
                else => return e,
            };
            defer dst.close(io);
            const stat = try dst.stat(io);

            var dst_writer = dst.writer(io, &.{});
            try dst_writer.seekTo(stat.size);
            try write_dep_file(allocator, io, cwd, artifact_d, &dst_writer.interface);
        }
    }
}

fn write_dep_file(allocator: std.mem.Allocator, io: std.Io, cwd: std.Io.Dir, dep_file_path: []const u8, writer: *std.Io.Writer) !void {
    const dep_file_content = try cwd.readFileAlloc(io, dep_file_path, allocator, .unlimited);
    defer allocator.free(dep_file_content);

    // std.Build.Cache does not support directories in the dep file.
    // Iterate over prerequisite and recursively replace any directories with the list of files inside.
    var first_target: bool = true;
    var it: std.Build.Cache.DepTokenizer = .{ .bytes = dep_file_content };
    while (it.next()) |token| {
        switch (token) {
            .target, .target_must_resolve => {
                if (first_target) {
                    first_target = false;
                } else {
                    try writer.writeAll("\n");
                }
                const target_path = if (token == .target) token.target else token.target_must_resolve;
                try writer.writeAll(target_path);
                try writer.writeAll(":");
            },
            .prereq, .prereq_must_resolve => {
                var resolve_buf: std.ArrayList(u8) = .empty;
                defer resolve_buf.deinit(allocator);

                const prereq_path = switch (token) {
                    .prereq => token.prereq,
                    .prereq_must_resolve => resolved: {
                        try token.resolve(allocator, &resolve_buf);
                        break :resolved resolve_buf.items;
                    },
                    else => unreachable,
                };

                const fstat = try cwd.statFile(io, prereq_path, .{});
                switch (fstat.kind) {
                    // TODO: Symlinks?
                    .file => {
                        try writer.writeAll(" ");
                        try writer.writeAll(prereq_path);
                    },
                    .directory => {
                        try walk_dep_directory(allocator, io, try cwd.openDir(io, prereq_path, .{
                            .iterate = true,
                            .follow_symlinks = false, // TODO: Symlinks?
                        }), writer);
                    },
                    else => {},
                }
            },
            else => |err| {
                var error_buf: std.ArrayList(u8) = .empty;
                defer error_buf.deinit(allocator);
                try err.printError(allocator, &error_buf);
                @panic(try std.fmt.allocPrint(allocator, "failed parsing {s}: {s}", .{ dep_file_path, error_buf.items }));
            },
        }
    }
    try writer.writeAll("\n");
}

fn walk_dep_directory(allocator: std.mem.Allocator, io: std.Io, root: std.Io.Dir, dep_writer: *std.Io.Writer) !void {
    var stack: std.ArrayList(std.Io.Dir) = .empty;
    try stack.append(allocator, root);

    while (stack.items.len > 0) {
        const directory: std.Io.Dir = stack.pop().?;
        var it = directory.iterate();
        while (try it.next(io)) |entry| {
            switch (entry.kind) {
                .directory => {
                    try stack.append(allocator, try directory.openDir(io, entry.name, .{
                        .iterate = true,
                        .follow_symlinks = false, // TODO: Symlinks?
                    }));
                },
                // TODO: Symlinks?
                .file => {
                    try dep_writer.writeAll(" ");
                    const full_path = try directory.realPathFileAlloc(io, entry.name, allocator);
                    defer allocator.free(full_path);
                    try render_filename(full_path, dep_writer);
                },
                else => {
                    const full_path = try directory.realPathFileAlloc(io, entry.name, allocator);
                    defer allocator.free(full_path);
                    std.log.debug("Dep file: ignored {s} (not a file)", .{full_path});
                },
            }
        }
    }
    return;
}

fn render_filename(token: []const u8, writer: *std.Io.Writer) !void {
    for (token) |c| {
        switch (c) {
            ' ' => try writer.writeByte('\\'),
            else => {},
        }
        try writer.writeByte(c);
    }
}
