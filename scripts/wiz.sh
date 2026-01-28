#!/bin/bash
# Wiz Exercise - Main Entry Script

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

case "${1:-}" in
    demo|d)
        shift
        exec "$SCRIPT_DIR/demo.sh" "$@"
        ;;
    build|b|deploy)
        shift
        exec "$SCRIPT_DIR/build.sh" "$@"
        ;;
    reset|r|destroy)
        shift
        exec "$SCRIPT_DIR/reset.sh" "$@"
        ;;
    *)
        echo "Wiz Technical Exercise - Helper Scripts"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  demo, d        Run vulnerability demonstrations"
        echo "  build, b       Build/deploy infrastructure"
        echo "  reset, r       Reset/destroy infrastructure"
        echo ""
        echo "Examples:"
        echo "  $0 demo                    # Interactive demo menu"
        echo "  $0 build --github          # Deploy via GitHub Actions"
        echo "  $0 build --local           # Deploy locally"
        echo "  $0 reset --github          # Destroy via GitHub Actions"
        echo "  $0 reset --show            # Show current resources"
        echo ""
        echo "Run '$0 <command> --help' for command-specific options."
        ;;
esac
