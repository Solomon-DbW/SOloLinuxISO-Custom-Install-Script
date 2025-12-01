#!/usr/bin/env bash
set -euo pipefail  # Add -u for unset variables, -o pipefail for pipe failures

# Create backup function
backup_if_exists() {
    if [ -e "$1" ]; then
        local backup="${1}.backup.$(date +%Y%m%d_%H%M%S)"
        cp -r "$1" "$backup"
        echo "Backed up $1 to $backup"
    fi
}

# Check for sudo access
if ! sudo -v; then
    echo "Error: This script requires sudo access"
    exit 1
fi

# Ensure installation occurs from home dir
cd ~

# Install Git and required tools
sudo pacman -S --noconfirm git base-devel

# Install fonts (removed gnome and gnome-tweaks - too heavy for Hyprland setup)
sudo pacman -S --noconfirm fontconfig ttf-jetbrains-mono-nerd noto-fonts noto-fonts-emoji noto-fonts-cjk ttf-dejavu jq
fc-cache -fv

# Starship prompt installation
curl -sS https://starship.rs/install.sh | sh -s -- -y
# Only append if not already present
grep -qxF 'eval "$(starship init bash)"' ~/.bashrc 2>/dev/null || echo 'eval "$(starship init bash)"' >> ~/.bashrc
grep -qxF 'eval "$(starship init zsh)"' ~/.zshrc 2>/dev/null || echo 'eval "$(starship init zsh)"' >> ~/.zshrc

# Zsh and plugins
sudo pacman -S --noconfirm zsh zsh-autosuggestions figlet exa zoxide fzf yad ghc dunst ripgrep # dunst is for notifs, yad is for cheatsheet and ripgrep is for Space+gs search function in Neovim

# Clean up existing oh-my-zsh if present
if [ -d ~/.oh-my-zsh ]; then
    backup_if_exists ~/.oh-my-zsh
    rm -rf ~/.oh-my-zsh
fi

# Oh-my-zsh install (unattended mode)
RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended

# Clean up existing zsh-autosuggestions plugin if present
if [ -d ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions ]; then
    rm -rf ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions
fi

# Zsh-autosuggestions plugin install
git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions

# Yay AUR helper install
if ! command -v yay &> /dev/null; then
    cd ~
    git clone https://aur.archlinux.org/yay.git
    cd yay
    makepkg -si --noconfirm
    cd ~
    rm -rf yay  # Cleanup
fi

# AUR packages
yay -S --noconfirm brave-bin hyprshade visual-studio-code-bin waypaper sddm-theme-mountain-git git-credential-manager hyprshot-gui

# Backup existing configs
backup_if_exists ~/.zshrc
backup_if_exists ~/.config

# Ensure .config exists
mkdir -p ~/.config

# Get SoloLinux config files
cd ~
# Remove existing clone if present
[ -d SoloLinux_GUI ] && rm -rf SoloLinux_GUI
git clone https://github.com/Solomon-DbW/SoloLinux_GUI

# Move config files carefully
cp SoloLinux_GUI/zshrcfile ~/.zshrc

# Copy config directories selectively (avoid copying .git and other unwanted files)
for item in SoloLinux_GUI/*; do
    basename_item=$(basename "$item")
    # Skip zshrcfile, .git directory, and other non-config items
    if [ "$basename_item" != "zshrcfile" ] && [ "$basename_item" != ".git" ] && [ "$basename_item" != "README.md" ]; then
        cp -r "$item" ~/.config/ 2>/dev/null || true
    fi
done

sudo cp -r SoloLinux_GUI/sddm.conf.d /etc/

# Cleanup
rm -rf SoloLinux_GUI SoloLinux

# Install Hyprland and related packages
sudo pacman -S --noconfirm hyprland hyprpaper hyprlock waybar rofi fastfetch cpufetch brightnessctl kitty virt-manager networkmanager nvim emacs sddm uwsm xdg-desktop-portal-hyprland qt5-wayland qt6-wayland polkit-kde-agent meson wireplumber pulseaudio pavucontrol archiso qemu yazi virtualbox

# Enable services
sudo systemctl enable NetworkManager
sudo systemctl enable sddm

# Making scripts executable
chmod +x ~/.config/hypr/scripts/* 2>/dev/null || true
chmod +x ~/.config/waybar/switch_theme.sh ~/.config/waybar/scripts/* 2>/dev/null || true

# Customize /etc/os-release for colour of #256897
sudo tee /etc/os-release > /dev/null <<'EOF'
NAME="SoloLinux"
PRETTY_NAME="SoloLinux"
ID=sololinux
ID_LIKE=arch
BUILD_ID=rolling
ANSI_COLOR="0;38;2;37;104;151"
HOME_URL="https://github.com/Solomon-DbW/SoloLinuxISO"
DOCUMENTATION_URL="https://github.com/Solomon-DbW/SoloLinuxISO"
SUPPORT_URL="https://github.com/Solomon-DbW/SoloLinuxISO"
BUG_REPORT_URL="https://github.com/Solomon-DbW/SoloLinuxISO"
PRIVACY_POLICY_URL="https://github.com/Solomon-DbW/SoloLinuxISO"
LOGO=archlinux-logo
EOF

# Change shell (will take effect after logout)
chsh -s $(which zsh)

echo "Setup complete! Please log out and log back in."
echo "Select Hyprland from the display manager to start the SoloLinux GUI."
