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
  # Install Chromium and dependencies for Mermaid CLI (mmdc)
  aptinstall chromium-browser || aptinstall chromium
  aptinstall fonts-liberation libappindicator3-1 libasound2 libatk-bridge2.0-0 libatk1.0-0 libcups2 libdbus-1-3 libgdk-pixbuf2.0-0 libnspr4 libnss3 libx11-xcb1 libxcomposite1 libxdamage1 libxrandr2 libgbm1 libpango-1.0-0 libpangocairo-1.0-0 libu2f-udev libvulkan1 libxss1 libxtst6
  texlivebin=''
  export DEBIAN_FRONTEND=noninteractive
  apt_update=0
  if ! type rsvg-convert > /dev/null 2>&1; then
    aptinstall librsvg2-bin
  fi
  if ! type inkscape > /dev/null 2>&1; then
    aptinstall inkscape
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
    texlivebin="$(dirname $(find /opt/texlive/texdir/bin -name tlmgr))"
    export PATH="${texlivebin}:${PATH}"
    sudo env "PATH=${PATH}" tlmgr path add
  else
    cd /tmp
    uri='https://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz'
    echo "Download ${uri}"
    HTTP_CODE=$(curl -sSL --remote-name --retry 4 \
      --write-out "%{response_code}" "${uri}"
    )
    if [ "${HTTP_CODE}" -lt 200 ] || [ "${HTTP_CODE}" -gt 299 ]; then
      echo "##[error]Unable to get ${uri}! Response code: ${HTTP_CODE}"
      exit 1
    fi
    zcat < install-tl-unx.tar.gz | tar xf -
    rm -f install-tl-unx.tar.gz
    TLTMP=$(readlink -f install-tl-*)
    TLPROFILE=$(readlink -f "${scriptPath}/texlive.profile")
    sudo perl "${TLTMP}/install-tl" --no-interaction --no-doc-install --no-src-install --profile="${TLPROFILE}"
    rm -rf "${TLTMP}"
    texlivebin="$(dirname $(find /opt/texlive/texdir/bin -name tlmgr))"
    export PATH="${texlivebin}:${PATH}"
    sudo env "PATH=${PATH}" tlmgr init-usertree
    TLPKG=$(readlink -f "${scriptPath}/texlive_packages.txt")
    sed -e 's/ *#.*$//' -e '/^ *$/d' "${TLPKG}" | xargs sudo env "PATH=${PATH}" tlmgr install
    sudo chmod -R o+w /opt/texlive/texdir/texmf-var
  fi
  if [ -n "${TF_BUILD-}" ]; then
    echo "##vso[task.prependpath]${texlivebin}"
  else
    echo "${texlivebin}" >> "${GITHUB_PATH}"
  fi
  TLREQ=$(readlink -f "${scriptPath}/requirements.txt")
  sudo env "PATH=${PATH}" pip3 --no-cache-dir install -r "${TLREQ}"
  # Install Mermaid CLI (mmdc) for Mermaid diagram rendering
  if ! type npm > /dev/null 2>&1; then
    aptinstall npm
  fi
  sudo npm install -g @mermaid-js/mermaid-cli
  # Configure Puppeteer for Ubuntu/Debian Chromium
  if [ -x /usr/bin/chromium-browser ]; then
    export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
  elif [ -x /usr/bin/chromium ]; then
    export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
  fi
  export PUPPETEER_ARGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu"
elif type apk > /dev/null 2>&1; then
  # Install Chromium and dependencies for Mermaid CLI (mmdc)
  apk add --no-cache chromium
  # Install Mermaid CLI (mmdc) for Mermaid diagram rendering
  if ! type npm > /dev/null 2>&1; then
    apk add --no-cache nodejs npm
  fi
  npm install -g @mermaid-js/mermaid-cli
  # Configure Puppeteer for Alpine Chromium
  export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
  export PUPPETEER_ARGS="--no-sandbox --disable-setuid-sandbox --disable-dev-shm-usage --disable-gpu"
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
  if ! type inkscape > /dev/null 2>&1; then
    apk add --no-cache inkscape
  fi
  if ! test -f '/usr/share/fonts/carlito/Carlito-Regular.ttf'; then
    apk add --no-cache --repository=https://dl-cdn.alpinelinux.org/alpine/edge/community font-carlito
  fi
  # Install additional fonts commonly used by Mermaid
  apk add --no-cache ttf-dejavu ttf-liberation fontconfig || echo "Warning: Could not install additional fonts"
  # Install font-misc-misc for additional fallback fonts
  apk add --no-cache font-misc-misc || echo "Warning: Could not install misc fonts"
  # Refresh font cache
  fc-cache -f -v || echo "Warning: Could not refresh font cache"
  # Debug: List available fonts for Mermaid
  echo "Available fonts for Mermaid rendering:"
  fc-list | grep -i -E "(dejavu|liberation|arial|carlito)" | head -10 || echo "No matching fonts found"
#  if type tlmgr > /dev/null 2>&1 && ! test -f '/opt/texlive/texdir/texmf-dist/tex/latex/lastpage/lastpage.sty'; then
#    tlmgr update --self
#    tlmgr option -- autobackup -1
#    tlmgr install lastpage
#  else
#    echo "Unable to find tlmgr in path: ${PATH}"
#    exit 1
#  fi
else
  echo 'Unable to find apt-get or apk!'
  exit 1
fi
# Set Puppeteer to use system Chromium if available
if [ -x /usr/bin/chromium-browser ]; then
  export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium-browser
elif [ -x /usr/bin/chromium ]; then
  export PUPPETEER_EXECUTABLE_PATH=/usr/bin/chromium
fi
# Only write to $GITHUB_ENV if it exists and its directory is present
if [ -n "$GITHUB_ENV" ] && [ -d "$(dirname "$GITHUB_ENV")" ]; then
  echo "export PUPPETEER_EXECUTABLE_PATH=\"$PUPPETEER_EXECUTABLE_PATH\"" >> "$GITHUB_ENV"
  echo "export PUPPETEER_ARGS=\"$PUPPETEER_ARGS\"" >> "$GITHUB_ENV"
fi
