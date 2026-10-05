# ~/.bash_profile

[[ -f ~/.bashrc ]] && . ~/.bashrc
# [[ -z $WAYLAND_DISPLAY && $(tty) == /dev/tty1 ]] && exec start-hyprland

# Remove comment above to autostart to hyprland when eww+lockscreen is setup
# Below is temporary compatibility for VMware

export LIBGL_ALWAYS_SOFTWARE=1
export WLR_RENDERER_ALLOW_SOFTARE=1
export WLR_NO_HARDWARE_CURSORS=1
