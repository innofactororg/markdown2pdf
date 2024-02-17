#!/usr/bin/env sh
set -e
if type apt-get > /dev/null 2>&1; then
  scriptPath="$(dirname "$(readlink -f "$0")")"
  echo "Script Path: ${scriptPath}"
  sudo apt-get -q --no-allow-insecure-repositories update
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get install --assume-yes --no-install-recommends \
    librsvg2-bin=2.* \
    fonts-noto-cjk \
    fonts-crosextra-carlito
  sudo apt-get install --assume-yes --no-install-recommends pandoc
  sudo rm -rf /var/lib/apt/lists/*
  cd /tmp
  HTTP_CODE=$(curl --show-error --silent --remote-name \
    --write-out "%{response_code}" \
    --header 'Accept: application/gzip' \
    --location https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz
  )
  if [[ ${HTTP_CODE} -lt 200 || ${HTTP_CODE} -gt 299 ]]; then
    echo "##[error]Unable to get install-tl-unx.tar.gz! Response code: ${HTTP_CODE}"
    exit 1
  fi
  zcat < install-tl-unx.tar.gz | tar xf -
  rm -f install-tl-unx.tar.gz
  TLTMP=$(readlink -f install-tl-*)
  TLPROFILE=$(readlink -f "${scriptPath}/texlive.profile")
  sudo perl "${TLTMP}/install-tl" --no-interaction --no-doc-install --no-src-install --profile="${TLPROFILE}"
  rm -rf "${TLTMP}"
  export PATH=/opt/texlive/texdir/bin/x86_64-linux:"${PATH}"
  echo '##vso[task.prependpath]/opt/texlive/texdir/bin/x86_64-linux'
  sudo env "PATH=${PATH}" tlmgr init-usertree
  TLPKG=$(readlink -f "${scriptPath}/texlive_packages.txt")
  sed -e 's/ *#.*$//' -e '/^ *$/d' "${TLPKG}" | xargs sudo env "PATH=${PATH}" tlmgr install
  sudo chmod -R o+w /opt/texlive/texdir/texmf-var
  TLREQ=$(readlink -f "${scriptPath}/pip_requirements.txt")
  sudo env "PATH=${PATH}" pip3 --no-cache-dir install -r "${TLREQ}"
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
