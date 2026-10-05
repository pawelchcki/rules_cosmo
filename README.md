# rules_cosmo

Bazel rules for checksum-pinned Cosmopolitan 4.0.2. Build actions use declared
compiler, assembler, linker, libc, headers and archive inputs, with an empty PATH.
Repository setup uses the shipped ELF APE loader to assimilate build tools; it
does not invoke a host compiler, binfmt handler or shell.

Build actions execute on Linux x86-64 and cross-compile both x86-64 and ARM64.
`cosmo_fat_binary` combines them into one APE for Linux, macOS (including Apple
Silicon), and Windows x64. BSD is outside the acceptance matrix. The artifact
embeds pinned Linux loaders and the Apple Silicon loader source. On first use,
Apple Silicon requires Xcode Command Line Tools to compile that loader. A writable
`TMPDIR` (or home directory) is needed for the extracted loader cache. The shell
bootstrap uses the bundled loader rather than a loader found on PATH.

```sh
bazel test //examples:hello_test //examples:native_test //examples:determinism_test
bazel build //examples:hello
```

Consumers add `bazel_dep(name = "rules_cosmo", version = "0.1.0")` and a pinned
`git_override`, use the `cosmo` extension, import `cosmocc` (and optionally
`cosmos_libraries`), and register `@rules_cosmo//cosmo:linux_x86_64_toolchain`.
Load `cosmo_fat_binary` from `@rules_cosmo//cosmo:defs.bzl`. `archives` accepts
Cosmopolitan-compatible static libraries, including Rust `no_std` staticlibs;
ordinary host libraries are not ABI-compatible. Supply x86-64 libraries with
`archives` and ARM64 libraries with `aarch64_archives`; headers and external
include mappings have matching `aarch64_` attributes. `includes` are package-relative
paths; declare all headers with `hdrs`. `cosmo_binary` remains available for thin
x86-64 APEs and ARM64 ELFs. ARM Rust runtimes must reserve x18 and x28 throughout
core, alloc, compiler-builtins, and the application. Standard precompiled ARM Rust
libraries do not meet that ABI requirement.

The optional Cosmos development archive supplies precompiled curl/OpenSSL and
compression libraries from 2025-04-23. Both archives are versioned and SHA-256
pinned. Library and tool licenses remain upstream's; generated binaries retain
Cosmopolitan's required license notices.
`determinism_test` compares every byte from separate compile/link actions with
different output paths. Local sandboxed tests pass with empty action PATH. The
native-platform workflow builds once and executes the same bytes on Linux x64,
Linux ARM64, Apple Silicon, Intel macOS, and Windows x64. Native acceptance is
established by those jobs, rather than inferred from cross-compilation.
BuildBuddy remote execution/cache validation is pending approval to upload the
declared source and toolchain inputs; local results do not establish RBE acceptance.
