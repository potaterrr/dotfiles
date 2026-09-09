# ~/.config/bash/40-functions.sh — functions

anime-fast() { ani-cli -a "$*"; }

# safe rm -rf: requires at least one explicit target
fdelete() {
    if [ $# -eq 0 ]; then
        echo "usage: fdelete <path>..." >&2
        return 2
    fi
    rm -rf -- "$@"
}
