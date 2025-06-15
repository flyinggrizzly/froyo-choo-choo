#!/bin/sh
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
REPO_URL="https://github.com/flyinggrizzly/froyo-choo-choo/archive/refs/heads/main.zip"
REPO_NAME="froyo-choo-choo"

# Get target directory and convert to absolute path
if [ -n "$1" ]; then
    # Handle absolute vs relative paths
    case "$1" in
        /*) TARGET_DIR="$1" ;;
        *) TARGET_DIR="$(pwd)/$1" ;;
    esac
else
    TARGET_DIR="$(pwd)"
fi

# Function to print colored output
print_info() { printf "${GREEN}==>${NC} %s\n" "$1"; }
print_warn() { printf "${YELLOW}Warning:${NC} %s\n" "$1"; }
print_error() { printf "${RED}Error:${NC} %s\n" "$1"; }

# Check for required commands
for cmd in git curl unzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        print_error "$cmd is required but not installed"
        exit 1
    fi
done

# Check for Nix
if ! command -v nix >/dev/null 2>&1; then
    print_warn "Nix is not installed"
    echo "  This project requires Nix for dependency management."
    echo "  Install Nix from: https://nixos.org/download.html"
    echo
fi

# Check for Nix flakes (if Nix is installed)
if command -v nix >/dev/null 2>&1; then
    if ! nix flake --help >/dev/null 2>&1; then
        print_warn "Nix flakes are not enabled"
        echo "  This project uses Nix flakes for reproducible builds."
        echo "  Enable flakes by adding to ~/.config/nix/nix.conf:"
        echo "    experimental-features = nix-command flakes"
        echo
    fi
fi

# Check for direnv
if ! command -v direnv >/dev/null 2>&1; then
    print_warn "direnv is not installed"
    echo "  direnv provides automatic environment activation."
    echo "  Install it, then  add to your shell: https://direnv.net/docs/hook.html"
    echo
fi

print_info "Copying $REPO_NAME to $TARGET_DIR"

# Create target directory if it doesn't exist
if [ ! -d "$TARGET_DIR" ]; then
    mkdir -p "$TARGET_DIR"
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d 2>/dev/null || mktemp -d -t 'froyo-install')
trap 'rm -rf "$TEMP_DIR"' EXIT

# Download repository
print_info "Downloading $REPO_NAME..."
if ! curl -fsSL -o "$TEMP_DIR/repo.zip" "$REPO_URL"; then
    print_error "Failed to download template repository"
    exit 1
fi

# Extract files
print_info "Extracting files..."
cd "$TEMP_DIR"
unzip -q repo.zip

# Find extracted directory (GitHub adds -main suffix)
EXTRACTED_DIR=$(find . -maxdepth 1 -type d -name "$REPO_NAME-*" | head -1)
if [ -z "$EXTRACTED_DIR" ]; then
    print_error "Failed to find extracted directory"
    exit 1
fi

# Copy all files to target directory
print_info "Copying files to target directory..."
cp -r "$TEMP_DIR/$EXTRACTED_DIR"/. "$TARGET_DIR/"

# Remove install.sh from target
rm -f "$TARGET_DIR/install.sh"

# Change to target directory for direnv
cd "$TARGET_DIR"

print_info "Setting up Git repository and staging all files (nix flakes only see staged files)..."
git init .
git add .

# Run direnv allow if available
if command -v direnv >/dev/null 2>&1; then
    print_info "Setting up direnv..."
    direnv allow

    # Reenter the directory to trigger direnv setup
    cd && cd "$TARGET_DIR"
else
    print_warn "direnv not found - skipping automatic setup"
fi

# Success message
print_info "Installation complete!"
echo
echo "Next steps:"
if [ "$TARGET_DIR" != "$(pwd)" ]; then
    echo "  cd $TARGET_DIR"
fi

# Show warnings for missing tools
missing_tools=0
if ! command -v nix >/dev/null 2>&1; then
    echo "  # Install Nix"
    missing_tools=1
elif ! nix flake --help >/dev/null 2>&1; then
    echo "  # Enable Nix flakes in ~/.config/nix/nix.conf"
    missing_tools=1
fi
if ! command -v direnv >/dev/null 2>&1; then
    echo "  # Install direnv and add shell hook"
    missing_tools=1
fi

if [ $missing_tools -eq 1 ]; then
    echo "  # Then run: direnv allow"
else
    echo "  # Environment is ready - run: nix develop"
fi
