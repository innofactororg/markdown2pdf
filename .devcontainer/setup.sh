#!/usr/bin/env sh
# shellcheck disable=SC2016
if [ -d "/var/run/docker.sock" ]; then
  # Grant access to the docker socket
  sudo chmod 666 /var/run/docker.sock
fi

if ! [ -d ~/.ssh ]; then
  if [ -d /tmp/.ssh-localhost ]; then
    command mkdir -p -- ~/.ssh
    sudo cp -R /tmp/.ssh-localhost/* ~/.ssh
    sudo chown -R -- "$(whoami):$(whoami)" ~ || true -- ?>/dev/null
    sudo chmod 400 -- ~/.ssh/*
  fi
fi

apk add --no-cache git wget jq librsvg font-noto-cjk zsh bash starship
apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community font-carlito font-fira-code-nerd shellcheck

pip install pre-commit

tlmgr update --self
tlmgr option -- autobackup -1
tlmgr install lastpage

if [ -f ~/.gitconfig ]; then
  rm ~/.gitconfig
fi

if ! [ -d ~/.config ]; then
  command mkdir -p -- ~/.config
fi
/bin/cp -f .devcontainer/starship.toml ~/.config/starship.toml
if ! [ -f ~/.zshrc ]; then
  touch ~/.zshrc
fi
if ! grep -q 'eval "$(starship init zsh)"' ~/.zshrc; then
  echo 'eval "$(starship init zsh)"' >>~/.zshrc
fi
