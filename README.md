# dotfiles
Ecosystem:
```
dotfiles/
├── bash/                      # stow package → ~
│   ├── .bashrc
│   └── .bash_profile          # login env, autostarts Hyprland on tty1
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
├── kitty/                     # stow package → ~/.config/kitty
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
git clone --recurse-submodules git@github.com:Flelk/dotfiles.git ~/dotfiles
sudo pacman -S --needed - < ~/dotfiles/packages.txt
yay -S --needed - < ~/dotfiles/aur.txt
cd ~/dotfiles && stow --no-folding bash hypr eww fuzzel launcher kitty nano
```
`--no-folding` matters for `launcher`: without it stow links all of `~/.local`
into the repo, and apps start writing their data into it.

Brightness (eww panel) uses DDC/CI: turn DDC/CI on in each monitor's menu.
