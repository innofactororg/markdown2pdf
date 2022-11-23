FROM pandoc/latex:2-ubuntu

# List installed latex packages
#RUN tlmgr info --only-installed --data name

# Install TeX Live packages
RUN tlmgr update --all && \
    tlmgr install \
    adjustbox \
    anysize \
    awesomebox \
    background \
    breqn \
    cite \
    collectbox \
    crop \
    ctable \
    enumitem \
    environ \
    eso-pic \
    everypage \
    extsizes \
    fancybox \
    fancyref \
    fontawesome5 \
    footmisc \
    footnotebackref \
    fvextra \
    index \
    jknapltx \
    koma-script \
    l3experimental \
    lastpage \
    latexbug \
    lineno \
    lwarp \
    ly1 \
    mathtools \
    mdframed \
    mdwtools \
    metalogo \
    mweights \
    needspace \
    ntgclass \
    pagecolor \
    pdfpages \
    powerdot \
    psfrag \
    rcs \
    sansmath \
    section \
    sectsty \
    seminar \
    sepnum \
    sourcecodepro \
    sourcesanspro \
    tcolorbox \
    textcase \
    thumbpdf \
    titling \
    trimspaces \
    typehtml \
    ucharcat \
    underscore \
    xecjk \
    xltxtra \
    zref

# Initialization for tlmgr
RUN tlmgr init-usertree

# Install apt-utils
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq update && apt-get -qq install apt-utils

# Install fonts
RUN apt-get -qq install fonts-noto-cjk fonts-crosextra-carlito fonts-crosextra-caladea

# Install image conversion tools
RUN apt-get -qq install poppler-utils librsvg2-bin

# Install python
RUN apt-get -qq install python3 python3-pip

# Install pandoc filters
RUN pip install pandoc-latex-environment

# Install pre-requisite packages for PowerShell
RUN apt-get -qq install wget apt-transport-https software-properties-common

# Download the Microsoft repository GPG keys
RUN wget -q "https://packages.microsoft.com/config/ubuntu/$(lsb_release -rs)/packages-microsoft-prod.deb"

# Register the Microsoft repository GPG keys
RUN dpkg -i packages-microsoft-prod.deb

# Update the list of packages after we added packages.microsoft.com
RUN apt-get -qq update

# Install PowerShell
RUN apt-get -qq install powershell

#SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Copy entrypoint script
#COPY entrypoint.sh /
#RUN chmod +x /entrypoint.sh

#ENTRYPOINT ["/entrypoint.sh"]
