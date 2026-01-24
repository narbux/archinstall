#!/usr/bin/env bash

set -euo pipefail


message()
{
    echo -e "\e[1;31m>> \e[0m$1"
}

message "** Starting userspace post install script **"

# User SSH setting
message "Downloading ssh keys"
if [[ ! -d "$HOME"/.ssh ]]; then
    mkdir $HOME/.ssh
fi

if [[ -e /usr/bin/curl ]]; then
    curl -SsL https://github.com/narbux.keys -o .ssh/authorized_keys
else
    message "ERROR: Could not find curl to download SSH keys"
fi

# Install PARU AUR helper
message "Downloading Paru"
git clone --depth=1 https://aur.archlinux.org/paru 1>/dev/null \
    && cd paru \
    && makepkg -si --noconfirm 1>/dev/null \
    && cd ~ \
    && rm -rf paru

# Install and configure zsh-antidote and zsh
message "Downloading ZSH-antidote and configuring ZSH"
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
source $HOME/.zshrc

message "Removing Bash leftover files"
rm $HOME/.bash_logout $HOME/.bash_profile $HOME/.bashrc

message "** DONE **"
