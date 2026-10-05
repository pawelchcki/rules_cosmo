"""Checksum-pinned compiler and optional prebuilt Cosmopolitan libraries."""

def _compiler_impl(ctx):
    ctx.download_and_extract(
        url = "https://cosmo.zip/pub/cosmocc/cosmocc-4.0.2.zip",
        sha256 = "85b8c37a406d862e656ad4ec14be9f6ce474c1b436b9615e91a55208aced3f44",
    )
    # GCC spawns its assembler/linker directly. Convert these APE build tools to
    # native ELF once at repository setup; no host compiler, shell or binfmt needed.
    tools = ["bin/apelink", "bin/fixupobj"]
    for arch in ["x86_64", "aarch64"]:
        tools += ["bin/" + arch + "-linux-cosmo-" + tool for tool in ["gcc", "objcopy", "objdump"]]
        tools += ["libexec/gcc/" + arch + "-linux-cosmo/14.1.0/" + tool for tool in ["as", "cc1", "cc1plus", "collect2", "ld.bfd"]]
    for tool in tools:
        result = ctx.execute([str(ctx.path("bin/ape-x86_64.elf")), str(ctx.path("bin/assimilate")), "-e", str(ctx.path(tool))])
        if result.return_code:
            fail("Cosmopolitan tool assimilation failed: " + result.stderr)
    ctx.file("BUILD.bazel", """
package(default_visibility = ["//visibility:public"])
exports_files(["bin/x86_64-linux-cosmo-gcc", "bin/aarch64-linux-cosmo-gcc", "bin/x86_64-linux-cosmo-objcopy", "bin/aarch64-linux-cosmo-objcopy", "bin/aarch64-linux-cosmo-objdump", "bin/ape-x86_64.elf", "bin/ape-aarch64.elf", "bin/ape-m1.c", "bin/apelink", "bin/fixupobj"])
filegroup(name = "files", srcs = glob(["bin/*-linux-cosmo-*", "bin/ape*", "bin/fixupobj", "include/**", "libexec/gcc/**", "lib/gcc/**", "*-linux-cosmo/lib/**"], exclude = ["**/*.bak", "**/dbg/**", "**/tiny/**", "**/optlinux/**"]))
""")

_compiler = repository_rule(implementation = _compiler_impl)

def _libraries_impl(ctx):
    ctx.download_and_extract(
        url = "https://cosmo.zip/pub/cosmos/dev/cosmos-dev-2025-4-23.tar.gz",
        sha256 = "fc4678d80cec7843571fb18d14642493d649146390b36d789769dc2aeae0ff4e",
        stripPrefix = "cosmos",
    )
    ctx.file("BUILD.bazel", """
package(default_visibility = ["//visibility:public"])
filegroup(name = "curl_headers", srcs = glob(["x86_64/include/curl/**"]))
filegroup(name = "curl_headers_aarch64", srcs = glob(["aarch64/include/curl/**"]))
filegroup(name = "curl", srcs = ["x86_64/lib/" + lib for lib in ["libcurl.a", "libpsl.a", "libunistring.a", "libssl.a", "libcrypto.a", "libz.a", "libzstd.a", "libbrotlidec.a", "libbrotlienc.a", "libbrotlicommon.a"]])
filegroup(name = "curl_aarch64", srcs = ["aarch64/lib/" + lib for lib in ["libcurl.a", "libpsl.a", "libunistring.a", "libssl.a", "libcrypto.a", "libz.a", "libzstd.a", "libbrotlidec.a", "libbrotlienc.a", "libbrotlicommon.a"]])
exports_files(["x86_64/lib/python3.12/site-packages/pip/_vendor/certifi/cacert.pem"])
""")

_libraries = repository_rule(implementation = _libraries_impl)

def _extension_impl(_ctx):
    _compiler(name = "cosmocc")
    _libraries(name = "cosmos_libraries")

cosmo = module_extension(implementation = _extension_impl)
