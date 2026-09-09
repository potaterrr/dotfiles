# ~/.config/bash/10-paths.sh — environment paths & editor

# prepend a path only if it is not already in PATH
path_add() {
    case ":$PATH:" in
        *":$1:"*) ;;
        *) PATH="$1:$PATH" ;;
    esac
}

# added in reverse so precedence matches: .local/bin > go/bin > .opencode/bin
[ -d /opt/nvim-linux-x86_64/bin ] && path_add /opt/nvim-linux-x86_64/bin
path_add "$HOME/.opencode/bin"
path_add "$HOME/go/bin"
path_add "$HOME/.local/bin"
export PATH

# default editor (LazyVim via Neovim)
if command -v nvim >/dev/null 2>&1; then
    export EDITOR=nvim VISUAL=nvim
fi

# anime CLI config
export ANI_CLI_PLAYER="mpv"
export ANI_CLI_OPTS="--fs"
