#!/bin/bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")" && pwd)"
BUILD_DIR="${ROOT}/build"

usage() {
    cat <<EOF
Usage:
  $0 [install_dir]              Configure and build (default prefix: /usr/local/app)
  TARS_INSTALL_PATH=<dir> $0    Same; env overrides default path

Subcommands:
  $0 prepare   Run: git submodule update --init --recursive
  $0 all       Configure and build (same as default with default prefix unless TARS_INSTALL_PATH is set)
  $0 install   Run cmake --install on $BUILD_DIR (use after a successful build)
  $0 cleanall  cmake clean + remove build/* except README.md
  $0 help      Show this help

Extra args after install_dir are passed to the native build tool (e.g. make), after -jN.
EOF
    exit "${1:-0}"
}

do_prepare() {
    (cd "$ROOT" && git submodule update --init --recursive)
}

do_configure_and_build() {
    local install_path="$1"
    shift
    mkdir -p "$BUILD_DIR"
    cmake -S "$ROOT" -B "$BUILD_DIR" \
        -DCMAKE_INSTALL_PREFIX="$install_path"
    local jobs total_cores
    total_cores="$(nproc 2>/dev/null || echo 4)"
    jobs="$((total_cores / 2))"
    (( jobs < 1 )) && jobs=1
    cmake --build "$BUILD_DIR" -- -j"${jobs}" "$@"
}

do_install() {
    cmake --install "$BUILD_DIR"
}

do_cleanall() {
    if [[ ! -d "$BUILD_DIR" ]]; then
        return 0
    fi
    (cd "$BUILD_DIR" && cmake --build . --target clean 2>/dev/null) || true
    shopt -s nullglob
    for f in "$BUILD_DIR"/*; do
        [[ "$(basename "$f")" == "README.md" ]] && continue
        rm -rf "$f"
    done
    shopt -u nullglob
}

resolve_install_path() {
    if [[ -n "${TARS_INSTALL_PATH:-}" ]]; then
        echo "$TARS_INSTALL_PATH"
    else
        echo "/usr/local/app"
    fi
}

# ---- main ----

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" || "${1:-}" == "help" ]]; then
    usage 0
fi

case "${1:-}" in
    prepare)
        do_prepare
        ;;
    cleanall)
        do_cleanall
        ;;
    install)
        do_install
        ;;
    all)
        shift || true
        do_configure_and_build "$(resolve_install_path)" "$@"
        ;;
    "")
        do_configure_and_build "$(resolve_install_path)"
        ;;
    *)
        if [[ "$1" != -* ]]; then
            INSTALL_PATH="$1"
            shift
            do_configure_and_build "$INSTALL_PATH" "$@"
        else
            usage 1
        fi
        ;;
esac
