#!/usr/bin/env bash
# Version management script for zrraw
# Usage: ./scripts/version.sh [patch|minor|major|prerelease] [prerelease-type]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_usage() {
    echo "Usage: $0 [patch|minor|major|prerelease] [prerelease-type]"
    echo ""
    echo "Commands:"
    echo "  patch       Bump patch version (1.0.0 -> 1.0.1)"
    echo "  minor       Bump minor version (1.0.0 -> 1.1.0)"
    echo "  major       Bump major version (1.0.0 -> 2.0.0)"
    echo "  prerelease  Bump prerelease version"
    echo ""
    echo "Prerelease types (for prerelease command):"
    echo "  alpha       Create/bump alpha version (1.0.0 -> 1.0.1-alpha.1)"
    echo "  beta        Create/bump beta version"
    echo "  rc          Create/bump release candidate"
    echo ""
    echo "Examples:"
    echo "  $0 patch                    # 1.0.0 -> 1.0.1"
    echo "  $0 minor                    # 1.0.0 -> 1.1.0"
    echo "  $0 prerelease alpha         # 1.0.0 -> 1.0.1-alpha.1"
    echo "  $0 prerelease beta          # 1.0.1-alpha.1 -> 1.0.1-beta.1"
}

get_current_version() {
    grep '^version = ' "$ROOT_DIR/bindings/rust/zrraw/Cargo.toml" | sed 's/version = "\(.*\)"/\1/'
}

parse_version() {
    local version="$1"
    if [[ $version =~ ^([0-9]+)\.([0-9]+)\.([0-9]+)(-([a-zA-Z]+)\.([0-9]+))?$ ]]; then
        MAJOR="${BASH_REMATCH[1]}"
        MINOR="${BASH_REMATCH[2]}"
        PATCH="${BASH_REMATCH[3]}"
        PRERELEASE_TYPE="${BASH_REMATCH[5]}"
        PRERELEASE_NUM="${BASH_REMATCH[6]}"
    else
        echo -e "${RED}Error: Invalid version format: $version${NC}"
        exit 1
    fi
}

bump_version() {
    local bump_type="$1"
    local prerelease_type="$2"
    local current_version
    current_version=$(get_current_version)
    
    echo -e "${BLUE}Current version: $current_version${NC}"
    
    parse_version "$current_version"
    
    case "$bump_type" in
        patch)
            if [[ -n $PRERELEASE_TYPE ]]; then
                # Remove prerelease suffix
                NEW_VERSION="$MAJOR.$MINOR.$PATCH"
            else
                NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))"
            fi
            ;;
        minor)
            NEW_VERSION="$MAJOR.$((MINOR + 1)).0"
            ;;
        major)
            NEW_VERSION="$((MAJOR + 1)).0.0"
            ;;
        prerelease)
            if [[ -z "$prerelease_type" ]]; then
                echo -e "${RED}Error: Prerelease type required for prerelease bump${NC}"
                print_usage
                exit 1
            fi
            
            if [[ -n $PRERELEASE_TYPE && $PRERELEASE_TYPE == "$prerelease_type" ]]; then
                # Same prerelease type, bump number
                NEW_VERSION="$MAJOR.$MINOR.$PATCH-$prerelease_type.$((PRERELEASE_NUM + 1))"
            elif [[ -n $PRERELEASE_TYPE ]]; then
                # Different prerelease type, reset to 1
                NEW_VERSION="$MAJOR.$MINOR.$PATCH-$prerelease_type.1"
            else
                # First prerelease
                NEW_VERSION="$MAJOR.$MINOR.$((PATCH + 1))-$prerelease_type.1"
            fi
            ;;
        *)
            echo -e "${RED}Error: Unknown bump type: $bump_type${NC}"
            print_usage
            exit 1
            ;;
    esac
    
    echo -e "${GREEN}New version: $NEW_VERSION${NC}"
    
    # Update Cargo.toml files
    echo -e "${YELLOW}Updating Cargo.toml files...${NC}"
    sed -i.bak "s/^version = \".*\"/version = \"$NEW_VERSION\"/" "$ROOT_DIR/bindings/rust/zrraw/Cargo.toml"
    sed -i.bak "s/^version = \".*\"/version = \"$NEW_VERSION\"/" "$ROOT_DIR/bindings/rust/zrraw-sys/Cargo.toml"
    
    # Update build.zig.zon
    echo -e "${YELLOW}Updating build.zig.zon...${NC}"
    sed -i.bak "s/\\.version = \".*\"/\.version = \"$NEW_VERSION\"/" "$ROOT_DIR/build.zig.zon"
    
    # Clean up backup files
    rm -f "$ROOT_DIR/bindings/rust/zrraw/Cargo.toml.bak"
    rm -f "$ROOT_DIR/bindings/rust/zrraw-sys/Cargo.toml.bak"
    rm -f "$ROOT_DIR/build.zig.zon.bak"
    
    echo -e "${GREEN}✅ Version updated to $NEW_VERSION${NC}"
    echo -e "${YELLOW}💡 Tip: Commit and push to main to automatically create a release${NC}"
}

# Main script
if [[ $# -eq 0 ]]; then
    print_usage
    exit 1
fi

bump_version "$@"
