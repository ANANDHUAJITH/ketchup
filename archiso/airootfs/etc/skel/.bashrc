# non-interactive shells: nothing to do
[[ $- != *i* ]] && return

[ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

# terminal window title
case ${TERM} in
    xterm*|rxvt*|Eterm*|aterm|kterm|gnome*|interix|konsole*)
        PROMPT_COMMAND='echo -ne "\033]0;${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\007"'
        ;;
    screen*)
        PROMPT_COMMAND='echo -ne "\033_${USER}@${HOSTNAME%%.*}:${PWD/#$HOME/\~}\033\\"'
        ;;
esac

alias df='df -h'                          # human-readable sizes
alias free='free -m'                      # show sizes in MB

shopt -s checkwinsize
shopt -s expand_aliases
shopt -s histappend

# Rust-based replacements, enabled only when installed
export EDITOR=hx VISUAL=hx PAGER=less
command -v eza >/dev/null && { alias ls='eza --icons=auto --group-directories-first'; alias ll='eza -l --icons=auto --git'; alias la='eza -la --icons=auto --git'; alias lt='eza --tree --level=2 --icons=auto'; }
command -v bat >/dev/null && { alias cat='bat --paging=never'; export MANPAGER="sh -c 'col -bx | bat -l man -p'"; }
command -v fd  >/dev/null && alias find='fd'
command -v rg  >/dev/null && alias grep='rg'
command -v dust >/dev/null && alias du='dust'
command -v procs >/dev/null && alias ps='procs'
command -v btm >/dev/null && alias top='btm'
command -v hx >/dev/null && alias vim='hx' && alias vi='hx'
command -v fastfetch >/dev/null && alias neofetch='fastfetch'
alias ketchup-update='sudo pacman -Syu && (command -v flatpak >/dev/null && flatpak update -y || true)'
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
command -v starship >/dev/null && eval "$(starship init bash)"
# y: yazi file manager that cd's into the folder you leave it in
y() { local t; t="$(mktemp -t yazi-cwd.XXXXXX)"; yazi "$@" --cwd-file="$t"; if cwd="$(cat -- "$t")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then cd -- "$cwd"; fi; rm -f -- "$t"; }
