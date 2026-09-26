#!/usr/bin/env bash
# Builds the matrix-rust-sdk fork for watchOS into Packages/MatrixRustSDK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${MATRIX_RUST_SDK_PATH:-$ROOT/../matrix-rust-sdk}"
PACKAGE="$ROOT/Packages/MatrixRustSDK"

export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:$PATH"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# aws-lc (reqwest's TLS, which the watch never uses: all traffic goes through URLSession) needs two
# fixes for arm64_32, applied to that target only:
# - Its cmake builder maps arm64_32-apple-watchos to CMAKE_OSX_ARCHITECTURES=arm64 (it only looks at
#   CARGO_CFG_TARGET_ARCH, "aarch64" for both watchOS device targets), so the objects fail to lipo
#   with the real arm64 slice. The toolchain file sets the Apple CMake variables correctly.
# - Its assembly mixes 64-bit limbs with arm64_32's 32-bit words. The toolchain file also turns on
#   OPENSSL_NO_ASM. Don't use AWS_LC_SYS_NO_ASM instead: it only allows opt-level 0, which the
#   SDK's reldbg profile doesn't give dependencies.
# The cc builder ignores the toolchain file, so force the cmake one for arm64_32.
export AWS_LC_SYS_CMAKE_BUILDER_arm64_32_apple_watchos=1
export CMAKE_TOOLCHAIN_FILE_arm64_32_apple_watchos="$ROOT/Tools/watchos-arm64_32.toolchain.cmake"

if [[ "${1:-}" == "--dev" ]]; then
  PROFILE=dev
  TARGETS=(--target aarch64-apple-watchos-sim)
else
  PROFILE=reldbg
  TARGETS=(--target aarch64-apple-watchos-sim --target aarch64-apple-watchos --target arm64_32-apple-watchos)
fi

cd "$SDK"
echo "Building $(git rev-parse --short HEAD) ($(git branch --show-current)) with profile $PROFILE"
# --features "" drops Sentry, which would open its own sockets.
cargo xtask swift build-framework \
  --profile "$PROFILE" \
  "${TARGETS[@]}" \
  --features "" \
  --watchos-deployment-target 11.0 \
  --sequentially \
  --components-path "$PACKAGE"

echo "SDK ready in $PACKAGE"
