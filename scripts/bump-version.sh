#!/bin/bash
# Version bump script for Cargo.toml
# Usage: ./scripts/bump-version.sh [patch|minor|major]

set -e

BUMP_TYPE="${1:-patch}"

# Get current version from Cargo.toml
CURRENT_VERSION=$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)"/\1/')

if [[ -z "$CURRENT_VERSION" ]]; then
    echo "❌ Could not read version from Cargo.toml"
    exit 1
fi

# Parse version parts
IFS='.' read -r MAJOR MINOR PATCH <<< "$CURRENT_VERSION"

# Bump the appropriate part
case "$BUMP_TYPE" in
    patch)
        PATCH=$((PATCH + 1))
        ;;
    minor)
        MINOR=$((MINOR + 1))
        PATCH=0
        ;;
    major)
        MAJOR=$((MAJOR + 1))
        MINOR=0
        PATCH=0
        ;;
    *)
        echo "❌ Invalid bump type: $BUMP_TYPE"
        echo "Usage: $0 [patch|minor|major]"
        exit 1
        ;;
esac

NEW_VERSION="${MAJOR}.${MINOR}.${PATCH}"

echo "📦 Bumping version: $CURRENT_VERSION → $NEW_VERSION"

# Update Cargo.toml
if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS sed requires empty string for -i
    sed -i '' "s/^version = \"$CURRENT_VERSION\"/version = \"$NEW_VERSION\"/" Cargo.toml
else
    # Linux sed
    sed -i "s/^version = \"$CURRENT_VERSION\"/version = \"$NEW_VERSION\"/" Cargo.toml
fi

# Verify the change
NEW_CHECK=$(grep '^version' Cargo.toml | head -1 | sed 's/.*"\(.*\)"/\1/')
if [[ "$NEW_CHECK" == "$NEW_VERSION" ]]; then
    echo "✓ Updated Cargo.toml to version $NEW_VERSION"
else
    echo "❌ Failed to update Cargo.toml"
    exit 1
fi

# Update Cargo.lock by running cargo check
echo "🔄 Updating Cargo.lock..."
cargo check --quiet 2>/dev/null || cargo check

echo "✓ Version bumped to $NEW_VERSION"
