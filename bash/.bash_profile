# ~/.bash_profile

[[ -f ~/.bashrc ]] && . ~/.bashrc

# Temporary compatibility for VMware
[[ -f ~/.vm_env ]] && . ~/.vm_env

# Autostart Hyprland on tty1 (CTRL + ALT + F2 EMERGENCY TERMINAL)
[[ -z $WAYLAND_DISPLAY && $(tty) == /dev/tty1 ]] && exec start-hyprland
