# build.crab

Thin wrapper around Cargo which integrates it with Zig's build system.

## Usage

```sh
zig fetch --save https://github.com/akarpovskii/build.crab/archive/refs/tags/v0.1.1.tar.gz
```

In `build.zig` (replace `crate` with the name of your crate):
```zig
const crate_lib_path = @import("build.crab").addCargoBuild(b, .{
    .name = "libcrate.a",
    .manifest_path = b.path("path/to/Cargo.toml"),
    // You can pass additional arguments to Cargo
    .cargo_args = &.{
        "--release",
        "--quiet",
    },
});

module.addLibraryPath(crate_lib_path.dirname());
module.linkSystemLibrary("crate", .{});
```

## Windows

![Hydra meme with Windows as the weird head!](./images/windows%20is%20the%20weird%20one.jpeg)

Windows, as always, is the weird one.

By default, Rust on Windows targets MSVC toolchain. This creates additional problems as you have to link against msvcrt, etc.

If you want to avoid that, you should target windows-gnu (see the [`example`](./example/build.zig)).
But that has its own problems as both Rust and Zig provide `compiler_rt.lib`. Most of the symbols in `compiler_rt` has weak linking, but not `___chkstk` and `___chkstk_ms`.

So if you want to link against a Rust library that needs these intrinsics, you should somehow resolve the conflict (though I'm not completely sure that it is safe to do).

For this purpose, `build.crab` provides an additional artifact called `strip_symbols` that repacks `.a` archive removing `.o` files containing conflicting functions (provided by the user).

```zig
const crate_lib_path = @import("build.crab").addStripSymbols(b, .{
    .name = "libcrate.a",
    .archive = b.path("path/to/libcrate.a"),
    .symbols = &.{
        "___chkstk_ms",
    },
});

module.addLibraryPath(crate_lib_path.dirname());
module.linkSystemLibrary("crate", .{});
```

See the [`buid.zig`](./example/build.zig) for a complete example.


On top of that, I recommend adding the following parameters to `Cargo.toml`:

```toml
[profile.release]
opt-level = "z"  # Optimize for size.
strip = true
lto = true
```

Otherwise, you again will have to link some obscure Windows libraries even if you don't need them.

And it also makes the size of the rust library smaller. Zig 0.12.0 has some problems consuming large archives on macOS (fixed in [#19758](https://github.com/ziglang/zig/issues/19718)) making it a good default choice.
