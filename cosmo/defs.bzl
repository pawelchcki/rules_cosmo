"""Portable x86-64 APE binaries built with declared, pinned tools and inputs."""

def _toolchain_impl(ctx):
    return [platform_common.ToolchainInfo(
        gcc = ctx.file.gcc,
        objcopy = ctx.file.objcopy,
        loader = ctx.file.loader,
        files = ctx.attr.files[DefaultInfo].files,
    )]

cosmo_toolchain = rule(
    implementation = _toolchain_impl,
    attrs = {
        "gcc": attr.label(allow_single_file = True, mandatory = True),
        "objcopy": attr.label(allow_single_file = True, mandatory = True),
        "loader": attr.label(allow_single_file = True, mandatory = True),
        "files": attr.label(mandatory = True),
    },
)

def _binary_impl(ctx):
    tc = ctx.toolchains["//cosmo:toolchain_type"]
    root = tc.gcc.dirname + "/.."
    lib = root + "/x86_64-linux-cosmo/lib"
    elf = ctx.actions.declare_file(ctx.label.name + ".elf")
    ape = ctx.actions.declare_file(ctx.label.name + ".com")
    args = [
        "-B" + root + "/bin/", "-D__COSMOPOLITAN__", "-D__COSMOCC__", "-D_COSMO_SOURCE",
        "-include", "libc/integral/normalize.inc", "-fportcosmo", "-fno-semantic-interposition",
        "-fno-pie", "-nostdinc", "-isystem", root + "/include", "-mno-red-zone",
        "-mno-tls-direct-seg-refs", "-fno-omit-frame-pointer", "-Os", "-ffunction-sections", "-fdata-sections",
        "-static", "-no-pie", "-nostdlib", "-fuse-ld=bfd", "-Wl,-z,noexecstack",
        "-Wl,--gc-sections", "-Wl,-T," + lib + "/ape.lds",
        "-Wl,-z,common-page-size=4096", "-Wl,-z,max-page-size=16384",
        "-o", elf.path, lib + "/ape-no-modify-self.o", lib + "/crt.o",
    ] + ctx.attr.copts
    for include in ctx.attr.includes:
        args += ["-I", ctx.label.package + "/" + include]
    for target, include in ctx.attr.external_includes.items():
        args += ["-I", target.label.workspace_root + "/" + include]
    args += [f.path for f in ctx.files.srcs]
    args += ["-Wl,--start-group"] + [f.path for f in ctx.files.archives] + ["-L" + lib, "-lcosmo", "-Wl,--end-group"] + ctx.attr.linkopts
    ctx.actions.run(
        executable = tc.gcc,
        arguments = args,
        inputs = depset(ctx.files.srcs + ctx.files.hdrs + ctx.files.archives + ctx.files.data, transitive = [tc.files] + [target[DefaultInfo].files for target in ctx.attr.external_includes]),
        outputs = [elf],
        env = {"PATH": "", "LC_ALL": "C", "SOURCE_DATE_EPOCH": "0"},
        mnemonic = "CosmoLink",
    )
    ctx.actions.run(
        executable = tc.objcopy,
        arguments = ["-S", "-O", "binary", elf.path, ape.path],
        inputs = depset([elf], transitive = [tc.files]),
        outputs = [ape],
        env = {"PATH": "", "LC_ALL": "C"},
        mnemonic = "CosmoAPE",
    )
    return [DefaultInfo(executable = ape, files = depset([ape]))]

cosmo_binary = rule(
    implementation = _binary_impl,
    executable = True,
    attrs = {
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
