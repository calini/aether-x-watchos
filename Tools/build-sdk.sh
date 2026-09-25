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
