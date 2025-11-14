#!/usr/bin/env bash

set -euo pipefail

echo "** Starting userspace post install script **"

# User SSH setting
echo -e "\t>> Downloading ssh keys"
if [[ ! -d "$HOME"/.ssh ]]; then
    mkdir $HOME/.ssh
fi

if [[ -e /usr/bin/curl ]]; then
    curl -SsL https://github.com/narbux.keys -o .ssh/authorized_keys
else
    echo -e "\t>>\033[31m\033ERROR:[0m Could not find curl to download SSH keys"
fi

# Install PARU AUR helper
echo -e "\t>> Downloading Paru"
git clone --depth=1 https://aur.archlinux.org/paru-bin 1>/dev/null \
    && cd paru-bin \
    && makepkg -si --noconfirm 1>/dev/null \
    && cd ~ \
    && rm -rf paru-bin

# Install and configure zsh-antidote and zsh
echo -e "\t>> Downloading ZSH-antidote and configuring ZSH"
paru -S --noconfirm zsh-antidote 1>/dev/null

cat <<'EOF' >> $HOME/.zsh_plugins.txt
mattmc3/ez-compinit
zsh-users/zsh-completions kind:fpath path=src

sindresorhus/pure kind:fpath

zsh-users/zsh-autosuggestions
zdharma-continuum/fast-syntax-highlighting kind:defer
EOF

cat <<'EOF' >> $HOME/.zshrc
EDITOR=nvim
VISUAL=nvim

source '/usr/share/zsh-antidote/antidote.zsh'
antidote load

chpwd() {
    exa
}

alias cat="bat -pp"
alias vim="nvim"
alias ls="exa"
alias ll="exa -lah"
alias tree="exa --tree"
alias ..="cd .."
alias cd="z"

autoload -Uz promptinit && promptinit && prompt pure

eval "$(zoxide init zsh)"
EOF

echo -e "\t>> Removing Bash leftover files"
rm $HOME/.bash_logout $HOME/.bash_profile $HOME/.bashrc

echo "** DONE **"
