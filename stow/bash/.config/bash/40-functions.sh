# ~/.config/bash/40-functions.sh — functions

anime-fast() {
    if ! command -v ani-cli >/dev/null 2>&1; then
        echo "anime-fast: ani-cli is not installed. Install it with: pkg_install ani-cli" >&2
        return 1
    fi
    ani-cli -a "$*"
}

# safe rm -rf: requires at least one explicit target
fdelete() {
    if [ $# -eq 0 ]; then
        echo "usage: fdelete <path>..." >&2
        return 2
    fi
    rm -rf -- "$@"
}
