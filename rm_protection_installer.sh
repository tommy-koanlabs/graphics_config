#!/bin/bash

# Script to install rm protection for home directory
# Usage: ./install-rm-protection.sh

set -e

BASHRC_FILE="$HOME/.bashrc"
BACKUP_FILE="$HOME/.bashrc.backup.$(date +%Y%m%d_%H%M%S)"

# Function to check if protection is already installed
check_existing_protection() {
    if grep -q "# Protect against accidentally deleting home directory" "$BASHRC_FILE" 2>/dev/null; then
        return 0  # Protection exists
    else
        return 1  # Protection doesn't exist
    fi
}

# Function to install the protection
install_protection() {
    echo "Installing rm protection for home directory..."
    
    # Create backup of existing .bashrc
    if [ -f "$BASHRC_FILE" ]; then
        cp "$BASHRC_FILE" "$BACKUP_FILE"
        echo "Backup created: $BACKUP_FILE"
    fi
    
    # Add the protection function to .bashrc
    cat >> "$BASHRC_FILE" << 'EOF'

# Protect against accidentally deleting home directory
rm() {
    for arg in "$@"; do
        # Check if trying to delete home directory specifically (not subdirectories)
        if [[ "$(realpath "$arg" 2>/dev/null)" == "$(realpath "$HOME" 2>/dev/null)" ]]; then
            echo "ERROR: Refusing to delete home directory: $HOME"
            echo "If you really want to do this, use: command rm $*"
            return 1
        fi
    done
    command rm "$@"
}
EOF
    
    echo "Protection installed successfully!"
}

# Function to test the protection
test_protection() {
    echo "Testing the protection..."
    
    # Source the updated .bashrc in current shell
    source "$BASHRC_FILE"
    
    # Test that the function exists
    if declare -f rm > /dev/null; then
        echo "✓ rm function is loaded"
        
        # Test with a safe command that should trigger protection
        echo "Testing protection with: rm ~"
        if rm ~ 2>&1 | grep -q "ERROR: Refusing to delete home directory"; then
            echo "✓ Protection is working correctly!"
        else
            echo "⚠ Warning: Protection may not be working as expected"
        fi
    else
        echo "⚠ Warning: rm function not found"
    fi
}

# Function to uninstall protection
uninstall_protection() {
    echo "Uninstalling rm protection..."
    
    if [ -f "$BACKUP_FILE" ]; then
        mv "$BACKUP_FILE" "$BASHRC_FILE"
        echo "Restored from backup: $BACKUP_FILE"
    else
        # Remove the protection block manually
        sed -i '/# Protect against accidentally deleting home directory/,/^}$/d' "$BASHRC_FILE"
        echo "Protection removed from .bashrc"
    fi
    
    echo "Protection uninstalled. Please restart your terminal or run: source ~/.bashrc"
}

# Main script logic
main() {
    echo "=== RM Home Directory Protection Installer ==="
    echo
    
    case "${1:-install}" in
        "install"|"")
            if check_existing_protection; then
                echo "Protection is already installed in $BASHRC_FILE"
                echo "Run with 'uninstall' to remove, or 'test' to test current protection"
            else
                install_protection
                test_protection
                echo
                echo "Installation complete! The protection is now active."
                echo "Please run 'source ~/.bashrc' or restart your terminal to activate in current session."
            fi
            ;;
        "test")
            if check_existing_protection; then
                test_protection
            else
                echo "Protection is not installed. Run without arguments to install."
            fi
            ;;
        "uninstall")
            if check_existing_protection; then
                uninstall_protection
            else
                echo "Protection is not currently installed."
            fi
            ;;
        "help"|"-h"|"--help")
            echo "Usage: $0 [install|test|uninstall|help]"
            echo
            echo "Commands:"
            echo "  install    - Install rm protection (default)"
            echo "  test       - Test if protection is working"
            echo "  uninstall  - Remove rm protection"
            echo "  help       - Show this help message"
            ;;
        *)
            echo "Unknown command: $1"
            echo "Run '$0 help' for usage information"
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"