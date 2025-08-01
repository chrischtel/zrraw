#!/usr/bin/env bash
# Helper script to copy the compiled Zig library to the Rust test directories
# Usage: ./scripts/copy-lib-for-tests.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

echo "Copying zrraw library for Rust tests..."

# Determine the library name based on the platform
if [[ "$OSTYPE" == "msys" || "$OSTYPE" == "cygwin" || "$OSTYPE" == "win32" ]]; then
    LIB_NAME="zrraw.dll"
elif [[ "$OSTYPE" == "darwin"* ]]; then
    LIB_NAME="libzrraw.dylib"
else
    LIB_NAME="libzrraw.so"
fi

LIB_PATH="$ROOT_DIR/zig-out/lib/$LIB_NAME"
RUST_DIR="$ROOT_DIR/bindings/rust"

if [[ ! -f "$LIB_PATH" ]]; then
    echo "Error: Library not found at $LIB_PATH"
    echo "Please build the Zig library first with: zig build"
    exit 1
fi

# Copy to target/debug/deps if it exists
if [[ -d "$RUST_DIR/target/debug/deps" ]]; then
    echo "Copying $LIB_NAME to target/debug/deps/"
    cp "$LIB_PATH" "$RUST_DIR/target/debug/deps/"
    
    # Also copy to any existing test executable directories
    find "$RUST_DIR/target/debug/deps" -name "zrraw*" -type f | while read test_exe; do
        if [[ -f "$test_exe" ]]; then
            test_dir=$(dirname "$test_exe")
            echo "Copying $LIB_NAME to $test_dir/"
            cp "$LIB_PATH" "$test_dir/"
        fi
    done
fi

# Also copy to the current working directory as a fallback
echo "Copying $LIB_NAME to current directory as fallback"
cp "$LIB_PATH" "$RUST_DIR/"

echo "✅ Library copied successfully!"
echo "💡 You can now run: cargo test --workspace --features \"zrraw-sys/compile-from-source\""
