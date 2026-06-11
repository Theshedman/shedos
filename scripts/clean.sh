#!/usr/bin/env bash
# ShedOS Clean Script

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m'

log_info() {
    echo -e "${YELLOW}[CLEAN]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[DONE]${NC} $1"
}

clean_build() {
    log_info "Removing build directory..."
    sudo rm -rf "$PROJECT_DIR/build"
}

clean_work() {
    log_info "Removing work directory..."
    sudo rm -rf "$PROJECT_DIR/build/work"
}

clean_output() {
    log_info "Removing output directory..."
    rm -rf "$PROJECT_DIR/out"
}

clean_test() {
    # Only the heavyweight VM artifacts — test/ holds 700+ tracked
    # fixture files that `rm -rf test` used to delete wholesale.
    log_info "Removing QEMU/OVMF test artifacts..."
    rm -f "$PROJECT_DIR"/test/*.qcow2 "$PROJECT_DIR"/test/OVMF_*.fd
}

clean_python() {
    log_info "Removing Python cache..."
    find "$PROJECT_DIR" -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
    find "$PROJECT_DIR" -type d -name "*.egg-info" -exec rm -rf {} + 2>/dev/null || true
    find "$PROJECT_DIR" -type f -name "*.pyc" -delete 2>/dev/null || true
}

clean_all() {
    clean_build
    clean_output
    clean_test
    clean_python
}

show_help() {
    echo "ShedOS Clean Script"
    echo ""
    echo "Usage: $0 [target]"
    echo ""
    echo "Targets:"
    echo "  all      Clean everything (default)"
    echo "  build    Clean build directory only"
    echo "  output   Clean output directory only"
    echo "  test     Clean test directory only"
    echo "  python   Clean Python cache only"
    echo "  help     Show this help message"
}

main() {
    local target="${1:-all}"

    case "$target" in
        all)
            clean_all
            ;;
        build)
            clean_build
            ;;
        output)
            clean_output
            ;;
        test)
            clean_test
            ;;
        python)
            clean_python
            ;;
        help|--help|-h)
            show_help
            exit 0
            ;;
        *)
            echo "Unknown target: $target"
            show_help
            exit 1
            ;;
    esac

    log_success "Clean complete"
}

main "$@"
