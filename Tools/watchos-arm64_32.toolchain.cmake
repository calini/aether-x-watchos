# CMake toolchain for arm64_32-apple-watchos, used only to work around two problems in the
# aws-lc-sys crate that the SDK build pulls in transitively (via reqwest's TLS, which
# the watch never actually uses — see AGENTS.md and Tools/build-sdk.sh).
#
# aws-lc-sys 0.45.0's own cmake builder maps Rust's CARGO_CFG_TARGET_ARCH == "aarch64"
# straight to CMAKE_OSX_ARCHITECTURES=arm64. That's correct for aarch64-apple-watchos,
# but wrong for arm64_32-apple-watchos: arm64_32 shares the aarch64 instruction set but
# is a distinct 32-bit-pointer Apple Watch ABI, and CARGO_CFG_TARGET_ARCH is "aarch64"
# for both. Left uncorrected, every object aws-lc-sys compiles for arm64_32 is silently
# mislabelled as plain arm64, which then fails to `lipo` together with the real arm64
# device slice ("same architectures (arm64) found in ...").
#
# Setting CMAKE_TOOLCHAIN_FILE (Tools/build-sdk.sh does this for this one target only)
# bypasses aws-lc-sys's own arch detection entirely, so the standard Apple-platform CMake
# variables are set here instead.
set(CMAKE_SYSTEM_NAME watchOS)
set(CMAKE_OSX_ARCHITECTURES arm64_32)
set(CMAKE_OSX_SYSROOT watchos)
set(CMAKE_OSX_DEPLOYMENT_TARGET 11.0)

# aws-lc's arm64 assembly assumes 64-bit words, which arm64_32 doesn't have, so build its portable C
# implementation instead. This is what AWS_LC_SYS_NO_ASM would do, without that variable's
# opt-level 0 requirement.
set(OPENSSL_NO_ASM ON CACHE BOOL "" FORCE)
