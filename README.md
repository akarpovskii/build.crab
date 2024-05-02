# build.crab

Thin wrapper around Cargo which integrates it with Zig's build system.

## Usage

```sh
zig fetch --save https://github.com/akarpovskii/build.crab/archive/refs/tags/v0.1.0.tar.gz
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
_ = run_build_crab.addDepFileOutputArg("librate.d");

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