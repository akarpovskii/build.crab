# build.crab

Thin wrapper around Cargo which integrates it with Zig's build system.

## Usage

```sh
zig fetch --save https://github.com/akarpovskii/build.crab/archive/refs/tags/v0.1.1.tar.gz
```

In `build.zig` (replace `crate` with the name of your crate):
```zig
const build_crab = b.dependency("build.crab", .{
    // Build in Debug mode to see debug logs
    .optimize = .ReleaseSafe,
});

const run_build_crab = b.addRunArtifact(build_crab.artifact("build_crab"));

// Output library file
// Zig will detect any changes in the file and re-link your module
run_build_crab.addArg("--out");
const crate_lib_path = run_build_crab.addOutputFileArg("libcrate.a");

// Deps info (.d) file (optional)
// Zig will detect any changes in the crate and re-run the step
run_build_crab.addArg("--deps");
_ = run_build_crab.addDepFileOutputArg("libcrate.d");

// Path to Cargo.toml
// build.crab will use this path to filter-out any third party artifacts
run_build_crab.addArg("--manifest-path");
_ = run_build_crab.addFileArg(b.path("path/to/Cargo.toml"));


// Create a target directory for Cargo in zig-cache
const cargo_target = b.addNamedWriteFiles("cargo-target");
const target_dir = cargo_target.getDirectory();
run_build_crab.addArg("--target-dir");
run_build_crab.addDirectoryArg(target_dir);

// You can pass additional arguments to Cargo
run_build_crab.addArgs(&[_][]const u8{
    "--",
    "--release",
    "--quiet",
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
const strip_chkstk_ms = b.addRunArtifact(build_crab.artifact("strip_symbols"));
strip_chkstk_ms.addArg("--archive");
strip_chkstk_ms.addFileArg(crate_lib_path);
strip_chkstk_ms.addArg("--temp-dir");
strip_chkstk_ms.addDirectoryArg(target_dir);
strip_chkstk_ms.addArg("--remove-symbol");
strip_chkstk_ms.addArg("___chkstk_ms");
strip_chkstk_ms.addArg("--output");
crate_lib_path = strip_chkstk_ms.addOutputFileArg("libcrate.a");
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
