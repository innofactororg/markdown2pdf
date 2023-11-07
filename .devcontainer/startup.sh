#!/usr/bin/env sh
if [ "${CODESPACES}" = "true" ]; then
  # Remove the default credential helper
  sudo sed -i -E 's/helper =.*//' /etc/gitconfig

  # Add one that just uses secrets available in the Codespace
  git config --global credential.helper '!f() { sleep 1; echo "username=${GITHUB_USER}"; echo "password=${GH_TOKEN}"; }; f'
fi

if [ ! $(git config --global --get safe.directory | grep "*" 2>&1) ]; then
  git config --global --add safe.directory "*"
fi
if [ "$(git config pull.rebase)" != "false" ]; then
  git config --global pull.rebase false
fi
if [ "$(git config user.name)" = "" ]; then
  echo "Warning: git user.name is not configured"
fi
if [ "$(git config user.email)" = "" ]; then
  echo "Warning: git user.email is not configured"
fi
