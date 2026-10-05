"""Portable x86-64 and ARM64 APE binaries built with declared, pinned tools and inputs."""

CosmoBinaryInfo = provider(fields = ["elf", "architecture"])

def _toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        gcc = ctx.file.gcc,
        gcc_aarch64 = ctx.file.gcc_aarch64,
        objcopy_aarch64 = ctx.file.objcopy_aarch64,
        loader_aarch64 = ctx.file.loader_aarch64,
        macos_loader_source = ctx.file.macos_loader_source,
        apelink = ctx.file.apelink,
        fixupobj = ctx.file.fixupobj,
        objcopy = ctx.file.objcopy,
        loader = ctx.file.loader,
        files = ctx.attr.files[DefaultInfo].files,
    )]

cosmo_toolchain = rule(
    implementation = _toolchain_impl,
    attrs = {
        "gcc_aarch64": attr.label(allow_single_file = True, mandatory = True),
        "objcopy_aarch64": attr.label(allow_single_file = True, mandatory = True),
        "loader_aarch64": attr.label(allow_single_file = True, mandatory = True),
        "macos_loader_source": attr.label(allow_single_file = True, mandatory = True),
        "apelink": attr.label(allow_single_file = True, mandatory = True),
        "fixupobj": attr.label(allow_single_file = True, mandatory = True),
        "gcc": attr.label(allow_single_file = True, mandatory = True),
        "objcopy": attr.label(allow_single_file = True, mandatory = True),
        "loader": attr.label(allow_single_file = True, mandatory = True),
        "files": attr.label(mandatory = True),
    },
)

def _binary_impl(ctx):
    tc = ctx.toolchains["//cosmo:toolchain_type"]
    root = tc.gcc.dirname + "/.."
    arch = ctx.attr.architecture
    lib = root + "/" + arch + "-linux-cosmo/lib"
    gcc = tc.gcc if arch == "x86_64" else tc.gcc_aarch64
    objcopy = tc.objcopy if arch == "x86_64" else tc.objcopy_aarch64
    startup = [lib + "/ape-no-modify-self.o", lib + "/crt.o"] if arch == "x86_64" else [lib + "/crt.o"]
    script = "ape.lds" if arch == "x86_64" else "aarch64.lds"
    flags = ["-mno-red-zone", "-mno-tls-direct-seg-refs"] if arch == "x86_64" else ["-fsigned-char", "-ffixed-x18", "-ffixed-x28"]
    elf = ctx.actions.declare_file(ctx.label.name + ".elf")
    ape = ctx.actions.declare_file(ctx.label.name + ".com")
    args = [
        "-B" + root + "/bin/", "-D__COSMOPOLITAN__", "-D__COSMOCC__", "-D_COSMO_SOURCE",
        "-include", "libc/integral/normalize.inc", "-fportcosmo", "-fno-semantic-interposition",
        "-fno-pie", "-nostdinc", "-isystem", root + "/include", "-fno-omit-frame-pointer", "-Os", "-ffunction-sections", "-fdata-sections",
        "-static", "-no-pie", "-nostdlib", "-fuse-ld=bfd", "-Wl,-z,noexecstack",
        "-Wl,--gc-sections", "-Wl,-T," + lib + "/" + script,
        "-Wl,-z,common-page-size=" + ("4096" if arch == "x86_64" else "16384"), "-Wl,-z,max-page-size=16384",
        "-o", elf.path,
    ] + startup + flags + ctx.attr.copts
    for include in ctx.attr.includes:
        args += ["-I", ctx.label.package + "/" + include]
    for target, include in ctx.attr.external_includes.items():
        args += ["-I", target.label.workspace_root + "/" + include]
    args += [f.path for f in ctx.files.srcs]
    args += ["-Wl,--start-group"] + [f.path for f in ctx.files.archives] + ["-L" + lib, "-lcosmo", "-Wl,--end-group"] + ctx.attr.linkopts
    ctx.actions.run(
        executable = gcc,
        arguments = args,
        inputs = depset(ctx.files.srcs + ctx.files.hdrs + ctx.files.archives + ctx.files.data, transitive = [tc.files] + [target[DefaultInfo].files for target in ctx.attr.external_includes]),
        outputs = [elf],
        env = {"PATH": "", "LC_ALL": "C", "SOURCE_DATE_EPOCH": "0"},
        mnemonic = "CosmoLink",
    )
    ctx.actions.run(
        executable = objcopy,
        arguments = (["-S", "-O", "binary"] if arch == "x86_64" else ["-S"]) + [elf.path, ape.path],
        inputs = depset([elf], transitive = [tc.files]),
        outputs = [ape],
        env = {"PATH": "", "LC_ALL": "C"},
        mnemonic = "CosmoAPE",
    )
    return [DefaultInfo(executable = ape, files = depset([ape])), CosmoBinaryInfo(elf = elf, architecture = arch)]

cosmo_binary = rule(
    implementation = _binary_impl,
    executable = True,
    attrs = {
        "architecture": attr.string(default = "x86_64", values = ["x86_64", "aarch64"]),
        "srcs": attr.label_list(allow_files = [".c"], mandatory = True),
        "hdrs": attr.label_list(allow_files = True),
        "archives": attr.label_list(allow_files = [".a"]),
        "data": attr.label_list(allow_files = True),
        "includes": attr.string_list(),
        "external_includes": attr.label_keyed_string_dict(),
        "copts": attr.string_list(),
        "linkopts": attr.string_list(),
    },
    toolchains = ["//cosmo:toolchain_type"],
)


def _fat_impl(ctx):
    tc = ctx.toolchains["//cosmo:toolchain_type"]
    python = ctx.toolchains["@rules_python//python:toolchain_type"].py3_runtime
    if not python.interpreter:
        fail("fat APE packaging requires a hermetic Python runtime")
    images = [ctx.attr.x86_64[CosmoBinaryInfo], ctx.attr.aarch64[CosmoBinaryInfo]]
    if [image.architecture for image in images] != ["x86_64", "aarch64"]:
        fail("fat binaries require one x86_64 and one aarch64 input")
    ape = ctx.actions.declare_file(ctx.label.name + ".com")
    ctx.actions.run(
        executable = python.interpreter,
        arguments = [ctx.file._package.path, tc.fixupobj.path, tc.apelink.path, tc.loader.path, tc.loader_aarch64.path, tc.macos_loader_source.path, ape.path] + [image.elf.path for image in images],
        inputs = depset([ctx.file._package] + [image.elf for image in images], transitive = [tc.files, python.files]),
        outputs = [ape],
        env = {"PATH": "", "LC_ALL": "C", "SOURCE_DATE_EPOCH": "0"},
        mnemonic = "CosmoFatAPE",
    )
    return [DefaultInfo(executable = ape, files = depset([ape]))]

_cosmo_fat_binary = rule(
    implementation = _fat_impl,
    executable = True,
    attrs = {
        "x86_64": attr.label(providers = [CosmoBinaryInfo], mandatory = True),
        "aarch64": attr.label(providers = [CosmoBinaryInfo], mandatory = True),
        "_package": attr.label(default = "//cosmo:package.py", allow_single_file = True),
    },
    toolchains = ["//cosmo:toolchain_type", "@rules_python//python:toolchain_type"],
)

def cosmo_fat_binary(name, archives = [], aarch64_archives = [], hdrs = [], aarch64_hdrs = [], external_includes = {}, aarch64_external_includes = {}, visibility = None, testonly = False, **kwargs):
    """Link both architectures and embed pinned Linux and Apple Silicon loaders."""
    cosmo_binary(name = name + "_x86_64", archives = archives, hdrs = hdrs, external_includes = external_includes, testonly = testonly, **kwargs)
    cosmo_binary(name = name + "_aarch64", architecture = "aarch64", archives = aarch64_archives, hdrs = aarch64_hdrs, external_includes = aarch64_external_includes, testonly = testonly, **kwargs)
    _cosmo_fat_binary(name = name, x86_64 = ":" + name + "_x86_64", aarch64 = ":" + name + "_aarch64", visibility = visibility, testonly = testonly)
