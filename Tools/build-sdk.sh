#!/usr/bin/env bash
# Builds the matrix-rust-sdk fork for watchOS into Packages/MatrixRustSDK.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SDK="${MATRIX_RUST_SDK_PATH:-$ROOT/../matrix-rust-sdk}"
PACKAGE="$ROOT/Packages/MatrixRustSDK"

export PATH="$HOME/.cargo/bin:/opt/homebrew/bin:$PATH"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
# aws-lc's assembly mixes 64-bit limbs with arm64_32's 32-bit words; it is only used by reqwest's TLS,
# which the watch never uses (all traffic goes through URLSession).
export AWS_LC_SYS_NO_ASM=1
# aws-lc-sys's cmake builder maps Rust's arm64_32-apple-watchos to CMAKE_OSX_ARCHITECTURES=arm64
# (it only looks at CARGO_CFG_TARGET_ARCH, "aarch64" for both arm64 and arm64_32 watchOS targets),
# so every object it compiles for arm64_32 comes out mislabelled as arm64 and fails to lipo
# together with the real arm64 device slice. Route that one target through a toolchain file that
# sets the Apple CMake variables correctly; see the file for details.
export CMAKE_TOOLCHAIN_FILE_arm64_32_apple_watchos="$ROOT/Tools/watchos-arm64_32.toolchain.cmake"

if [[ "${1:-}" == "--dev" ]]; then
  PROFILE=dev
  TARGETS=(--target aarch64-apple-watchos-sim)
else
  # reldbg forces aws-lc-sys to opt-level 3 (via its package."*" override), which panics
  # under AWS_LC_SYS_NO_ASM=1. The fork's `watch` profile inherits reldbg but keeps
  # aws-lc-sys at opt-level 0, since aws-lc only backs reqwest's TLS (unused on the watch).
  PROFILE=watch
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
