#!/usr/bin/env sh
set -e
if type apt-get > /dev/null 2>&1; then
  sudo apt-get -q --no-allow-insecure-repositories update
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get install --assume-yes --no-install-recommends \
    librsvg2-bin=2.* \
    fonts-noto-cjk \
    fonts-crosextra-carlito
  sudo apt-get install --assume-yes --no-install-recommends pandoc
  sudo rm -rf /var/lib/apt/lists/*
  cd /tmp
  wget https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
  zcat < install-tl-unx.tar.gz | tar xf -
  rm -f install-tl-unx.tar.gz
  TLTMP=$(readlink -f install-tl-*)
  wget https://raw.githubusercontent.com/pandoc/dockerfiles/master/common/latex/texlive.profile
  TLPROFILE=$(readlink -f texlive.profile)
  sudo perl "$TLTMP/install-tl" --no-interaction --no-doc-install --no-src-install --profile="$TLPROFILE"
  rm -f "$TLPROFILE"
  rm -rf "$TLTMP"
  export PATH=/opt/texlive/texdir/bin/x86_64-linux:"$PATH"
  echo '##vso[task.prependpath]/opt/texlive/texdir/bin/x86_64-linux'
  sudo env "PATH=$PATH" tlmgr init-usertree
  wget https://raw.githubusercontent.com/pandoc/dockerfiles/master/common/latex/packages.txt
  TLPKG=$(readlink -f packages.txt)
  sed -e 's/ *#.*$//' -e '/^ *$/d' "$TLPKG" | xargs sudo env "PATH=$PATH" tlmgr install
  rm -f "$TLPKG"
  wget https://raw.githubusercontent.com/pandoc/dockerfiles/master/common/extra/packages.txt
  TLPKG=$(readlink -f packages.txt)
  sed -e 's/ *#.*$//' -e '/^ *$/d' "$TLPKG" | sudo env "PATH=$PATH" xargs tlmgr install
  rm -f "$TLPKG"
  sudo env "PATH=$PATH" tlmgr install lastpage
  sudo chmod -R o+w /opt/texlive/texdir/texmf-var
  wget https://raw.githubusercontent.com/pandoc/dockerfiles/master/common/extra/requirements.txt
  TLREQ=$(readlink -f requirements.txt)
  sudo env "PATH=$PATH" pip3 --no-cache-dir install -r "$TLREQ"
  rm -f "$TLREQ"
elif type apk > /dev/null 2>&1; then
  apk add --no-cache git curl jq librsvg font-noto-cjk
  apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community font-carlito
  if type tlmgr > /dev/null 2>&1; then
    tlmgr update --self
    tlmgr install lastpage
  else
    echo 'Unable to find tlmgr!'
    exit 1
  fi
else
  echo 'Unable to find apt-get and apk!'
  exit 1
fi
