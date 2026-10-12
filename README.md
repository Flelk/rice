# dotfiles
Ecosystem:
```
dotfiles/
├── bash/                      # stow package → ~
│   ├── .bashrc
│   ├── .bash_profile          # login env, autostarts Hyprland on tty1
│   └── .local/bin/strike      # new-terminal intro: snow + hail pile on a small > (strike-classic: old bash rain)
├── hypr/                      # stow package → ~/.config/hypr
│   └── .config/hypr/
│       ├── hyprland.lua       # monitor, programs, autostart, env, binds
│       ├── hyprlock.conf      # lock screen
│       └── xdph.conf          # screen-share portal → fuzzel picker
├── eww/                       # stow package → ~/.config/eww
│   └── .config/eww/           # bar + power panel (eww.yuck, eww.scss, scripts/)
├── fuzzel/                    # stow package → ~/.config/fuzzel
│   └── .config/fuzzel/        # launcher theme
├── launcher/                  # stow package → ~/.config/launcher, ~/.local
│   ├── .config/launcher/apps  # launcher entries: Name|command
│   └── .local/                # launch, xdph-fuzzel-picker, discord.desktop
├── fastfetch/                 # stow package → ~/.config/fastfetch
│   ├── .config/fastfetch/     # config.jsonc: os, kernel, packages, cpu, gpu, memory + logos
│   └── .local/bin/fetch       # fastfetch with the animated logo (kitty)
├── kitty/                     # stow package → ~/.config/kitty
├── mako/                      # stow package → ~/.config/mako (notifications)
├── nano/                      # stow package → ~/.config/nano
├── wallpapers/                # submodule
├── packages.txt               # pacman packages
├── aur.txt                    # AUR packages
├── vm/                        # VM only — don't stow on laptop
│   └── .vm_env                # VMware software-render vars
└── README.md                  # this file
```

## Install
```
git clone --recurse-submodules git@github.com:Flelk/rice.git ~/dotfiles
sudo pacman -S --needed - < ~/dotfiles/packages.txt
yay -S --needed - < ~/dotfiles/aur.txt
cd ~/dotfiles && stow --no-folding bash hypr eww fuzzel fastfetch launcher kitty mako nano
```
`--no-folding` matters for `launcher`: without it stow links all of `~/.local`
into the repo, and apps start writing their data into it.

Then turn on wifi/bluetooth (the eww net panel) and power modes (the power panel) and unlock the keyring at login:
```
sudo systemctl enable --now NetworkManager bluetooth power-profiles-daemon
```
In `/etc/pam.d/login`, add `auth optional pam_gnome_keyring.so` after the last `auth` line
and `session optional pam_gnome_keyring.so auto_start` after the last `session` line.

Brightness (eww panel) uses the backlight on a laptop and DDC/CI on a desktop: turn DDC/CI
on in each monitor's menu.
