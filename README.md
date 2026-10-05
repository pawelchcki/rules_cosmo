# rules_cosmo

Bazel rules for checksum-pinned Cosmopolitan 4.0.2. Build actions use declared
compiler, assembler, linker, libc, headers and archive inputs, with an empty PATH.
Repository setup uses the shipped ELF APE loader to assimilate build tools; it
does not invoke a host compiler, binfmt handler or shell.

The initial execution platform is Linux x86-64. Outputs are x86-64 APEs for
Linux, Intel macOS, Windows and the BSDs. Native ARM64 and fat binaries are not
implemented yet. `bazel run` depends on the host's APE execution support; tests
use the pinned loader explicitly.

```sh
bazel test //examples:hello_test //examples:determinism_test
bazel build //examples:hello
```

Consumers add `bazel_dep(name = "rules_cosmo", version = "0.1.0")` and a pinned
`git_override`, use the `cosmo` extension, import `cosmocc` (and optionally
`cosmos_libraries`), and register `@rules_cosmo//cosmo:linux_x86_64_toolchain`.
Load `cosmo_binary` from `@rules_cosmo//cosmo:defs.bzl`. `archives` accepts
Cosmopolitan-compatible static libraries, including Rust `no_std` staticlibs;
ordinary host libraries are not ABI-compatible. `includes` are execution-root
relative include paths; declare all headers with `hdrs`.

The optional Cosmos development archive supplies precompiled curl/OpenSSL and
compression libraries from 2025-04-23. Both archives are versioned and SHA-256
pinned. Library and tool licenses remain upstream's; generated binaries retain
Cosmopolitan's required license notices.
`determinism_test` compares every byte from separate compile/link actions with
different output paths. Local sandboxed tests pass with empty action PATH. The
initial hello APE digest is
`4ba02cc83c147ae8e1c0d04eccd9a873ff1b8b5f912641aaa9071d2b70b63590`.
BuildBuddy remote execution/cache validation is pending approval to upload the
declared source and toolchain inputs; local results do not establish RBE acceptance.
