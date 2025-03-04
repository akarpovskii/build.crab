# build.crab

Thin wrapper around Cargo which integrates it with Zig's build system. <br>
Cross-compilation is supported.

## Requirements

Please see `.minimum_zig_version` field of the `build.zig.zon` file.

## Usage

```sh
zig fetch --save git+https://github.com/akarpovskii/build.crab#stable
```

In `build.zig` (replace `crate` with the name of your crate):
```zig
const build_crab = @import("build_crab");
const crate_artifacts = build_crab.addCargoBuild(
    b,
    .{
        .manifest_path = b.path("path/to/Cargo.toml"),
        // You can pass additional arguments to Cargo
        .cargo_args = &.{
            "--release",
            "--quiet",
        },
    },
    .{
        // Set to .Debug to see debug logs,
        // defaults to the same optimization level as your package.
        .optimize = .ReleaseSafe,
    },
);

module.addLibraryPath(crate_artifacts);
module.linkSystemLibrary("crate", .{});
```

See [`example`](./example/build.zig) for the other examples.

## Cross-compilation

Use `target` argument to specify the cross-compilation target:

```zig
const target = b.standardTargetOptions(.{});
const build_crab = @import("build_crab");
const crate_artifacts = build_crab.addCargoBuild(
    b,
    .{
        // Cargo params
    },
    .{
        .target = target,
    },
);
```

`build.crab` binaries will still be built for the native target, but it will try its best to convert Zig's target triple to Rust and call `cargo build` with the appropriate `--target` argument.

See [`rust.zig`](src/rust.zig) and the tests at the bottom to know how the conversion is done.

## Override Rust target

Use `rust_target` from `CargoConfig` to override the `--target` argument passed to `cargo build`:

```zig
const target = b.standardTargetOptions(.{});
const build_crab = @import("build_crab");
const crate_artifacts = build_crab.addCargoBuild(
    b,
    .{
        .rust_target = .{
            // Override only some parts
            .override = .{ .vendor = .{ .custom = "alpine" } },

            // Or specify the value explicitly
            // .value = "x86_64-alpine-linux-musl",
        },
        ...
    },
    ...
);
```

## Windows

### Toolchain

By default, Rust on Windows targets MSVC toolchain. This creates additional problems as you have to link against msvcrt, etc.

If you want to avoid that, you can target windows-gnu. This is the default behavior of `build.crab`.

### Unused symbols

I recommend adding the following parameters to `Cargo.toml`:

```toml
[profile.release]
opt-level = "z"  # Optimize for size.
strip = true
lto = true
```

Otherwise, you will have to link some obscure Windows libraries even if you don't use them.

And it also makes the size of the rust library smaller.

### Duplicate symbols [obsolete since Zig 0.14.0 / build.crab 0.1.8]

Both Rust and Zig provide `compiler_rt.lib` with most of the symbols having weak linking, but not `___chkstk` and `___chkstk_ms`.

So if you want to link against a Rust library that needs these intrinsics, you should somehow resolve the conflict (though I'm not completely sure that it is safe to do).

For this purpose, `build.crab` provides an additional artifact called `strip_symbols` that repacks `.a` archive removing `.o` files containing conflicting functions (provided by the user).

```zig
const crate_lib_path = @import("build_crab").addStripSymbols(b, .{
    .name = "libcrate.a",
    .archive = b.path("path/to/libcrate.a"),
    .symbols = &.{
        "___chkstk_ms",
    },
});

module.addLibraryPath(crate_lib_path.dirname());
module.linkSystemLibrary("crate", .{});
```

If you use `addRustStaticlib`, this is already taken care of for you. See the [`buid.zig`](./example/build.zig) for a complete example.
