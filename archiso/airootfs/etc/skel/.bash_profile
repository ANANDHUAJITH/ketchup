[[ -f ~/.bashrc ]] && . ~/.bashrc

# Start NetworkManager on graphical login. greetd starts niri through niri-session, which
# re-runs in the login shell, so this file is read once per login before niri is up.
# No tty check: greetd sessions have no tty name. -n never prompts, and
# /etc/sudoers.d/ketchup-networkmanager allows exactly this command for the wheel group.
if [ -z "${DISPLAY}" ] && [ -z "${WAYLAND_DISPLAY}" ] && [ -z "${SSH_CONNECTION}" ]; then
    sudo -n /usr/bin/systemctl start NetworkManager.service >/dev/null 2>&1 || true
fi
