#
# ~/.bashrc
#

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

[ -r /usr/share/bash-completion/bash_completion ] && . /usr/share/bash-completion/bash_completion

# Change the window title of X terminals
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

# Bash won't get SIGWINCH if another process is in the foreground.
# Enable checkwinsize so that bash will check the terminal size when
# it regains control.  #65623
# http://cnswww.cns.cwru.edu/~chet/bash/FAQ (E11)
shopt -s checkwinsize

shopt -s expand_aliases

# export QT_SELECT=4

# Enable history appending instead of overwriting.  #139609
shopt -s histappend

#neofetch

# ---- Ketup: Rust-powered shell tools (only active if installed) ----
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
alias ketup-update='sudo pacman -Syu && (command -v flatpak >/dev/null && flatpak update -y || true)'
command -v zoxide >/dev/null && eval "$(zoxide init bash)"
command -v starship >/dev/null && eval "$(starship init bash)"
# y: yazi file manager that cd's into the folder you leave it in
y() { local t; t="$(mktemp -t yazi-cwd.XXXXXX)"; yazi "$@" --cwd-file="$t"; if cwd="$(cat -- "$t")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then cd -- "$cwd"; fi; rm -f -- "$t"; }
