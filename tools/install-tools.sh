#!/usr/bin/env sh
if type apt-get > /dev/null 2>&1; then
  apt-get -q --no-allow-insecure-repositories update
  DEBIAN_FRONTEND=noninteractive
  apt-get install --assume-yes --no-install-recommends jq fonts-noto-cjk fonts-crosextra-carlito
  rm -rf /var/lib/apt/lists/*
elif type apk > /dev/null 2>&1; then
  apk add --no-cache git curl jq librsvg font-noto-cjk
  apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community font-carlito
else
  echo 'Unable to find apt-get and apk!'
  exit 1
fi
if type tlmgr > /dev/null 2>&1; then
  tlmgr update --self
  tlmgr install lastpage
else
  echo 'Unable to find tlmgr!'
  exit 1
fi
