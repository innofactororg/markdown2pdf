#!/usr/bin/env sh
set -e
aptinstall() {
  if [ "${apt_update}" -eq 0 ]; then
    sudo apt-get -q --no-allow-insecure-repositories update
    apt_update=1
  fi
  sudo apt-get install --assume-yes --no-install-recommends "${1}"
}
if type apt-get > /dev/null 2>&1; then
  export DEBIAN_FRONTEND=noninteractive
  apt_update=0
  if ! type rsvg-convert > /dev/null 2>&1; then
    aptinstall librsvg2-bin
  fi
  if ! test -f '/usr/share/fonts/opentype/noto/NotoSansCJK-Regular.ttc'; then
    aptinstall fonts-noto-cjk
  fi
  if ! test -f '/usr/share/fonts/truetype/crosextra/Carlito-Regular.ttf'; then
    aptinstall fonts-crosextra-carlito
  fi
  if ! type pandoc > /dev/null 2>&1; then
    aptinstall pandoc
  fi
  sudo rm -rf /var/lib/apt/lists/* > /dev/null 2>&1
  scriptPath="$(dirname "$(readlink -f "$0")")"
  if test -f "/opt/texlive/texdir/install-tl"; then
    export PATH="$(readlink -f /opt/texlive/texdir/bin/default):${PATH}"
    sudo env "PATH=${PATH}" tlmgr path add
  else
    cd /tmp
    HTTP_CODE=$(curl --show-error --silent --remote-name \
      --write-out "%{response_code}" \
      --header 'Accept: application/gzip' \
      --location https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
    )
    if [ "${HTTP_CODE}" -lt 200 ] || [ "${HTTP_CODE}" -gt 299 ]; then
      echo "##[error]Unable to get install-tl-unx.tar.gz! Response code: ${HTTP_CODE}"
      exit 1
    fi
    zcat < install-tl-unx.tar.gz | tar xf -
    rm -f install-tl-unx.tar.gz
    TLTMP=$(readlink -f install-tl-*)
    TLPROFILE=$(readlink -f "${scriptPath}/texlive.profile")
    sudo perl "${TLTMP}/install-tl" --no-interaction --no-doc-install --no-src-install --profile="${TLPROFILE}"
    rm -rf "${TLTMP}"
    export PATH="$(readlink -f /opt/texlive/texdir/bin/default):${PATH}"
    sudo env "PATH=${PATH}" tlmgr init-usertree
    TLPKG=$(readlink -f "${scriptPath}/texlive_packages.txt")
    sed -e 's/ *#.*$//' -e '/^ *$/d' "${TLPKG}" | xargs sudo env "PATH=${PATH}" tlmgr install
    sudo chmod -R o+w /opt/texlive/texdir/texmf-var
  fi
  echo '##vso[task.prependpath]/opt/texlive/texdir/bin/default'
  TLREQ=$(readlink -f "${scriptPath}/requirements.txt")
  sudo env "PATH=${PATH}" pip3 --no-cache-dir install -r "${TLREQ}"
elif type apk > /dev/null 2>&1; then
  if ! type git > /dev/null 2>&1; then
    apk add --no-cache git
  fi
  if ! type curl > /dev/null 2>&1; then
    apk add --no-cache curl
  fi
  if ! type jq > /dev/null 2>&1; then
    apk add --no-cache jq
  fi
  if ! type rsvg-convert > /dev/null 2>&1; then
    apk add --no-cache librsvg
  fi
  if ! test -f '/usr/share/fonts/noto/NotoSansCJK-Regular.ttc'; then
    apk add --no-cache font-noto-cjk
  fi
  if ! test -f '/usr/share/fonts/carlito/Carlito-Regular.ttf'; then
    apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community font-carlito
  fi
  if type tlmgr > /dev/null 2>&1 && ! test -f '/opt/texlive/texdir/texmf-dist/tex/latex/lastpage/lastpage.sty'; then
    tlmgr update --self
    tlmgr install lastpage
  else
    echo "Unable to find tlmgr in path: ${PATH}"
    exit 1
  fi
else
  echo 'Unable to find apt-get or apk!'
  exit 1
fi
