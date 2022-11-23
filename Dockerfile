FROM mcr.microsoft.com/powershell

# Install apt-utils wget and curl
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get -qq update
RUN apt-get -qq install apt-utils
RUN apt-get -qq install wget curl

# Install TeX Live
RUN apt-get -qq install texlive

# Initialization for tlmgr
RUN tlmgr init-usertree

# List installed latex packages
#RUN tlmgr info --only-installed --data name

# Update TeX Live
#RUN tlmgr update --self

# Update TeX Live packages
#RUN tlmgr update --all

# Install TeX Live packages
RUN tlmgr install \
    adjustbox \
    anysize \
    awesomebox \
    background \
    breqn \
    catchfile \
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
    hardwrap \
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

# Install pandoc
RUN wget -qO- "https://github.com/jgm/pandoc/releases/download/2.19.2/pandoc-2.19.2-linux-amd64.tar.gz" | tar xzf - --strip-components 1 -C "/usr/local/"

# Install fonts
RUN apt-get -qq install fonts-noto-cjk fonts-crosextra-carlito fonts-crosextra-caladea

# Install image conversion tools
RUN apt-get -qq install poppler-utils librsvg2-bin

# Install python
RUN apt-get -qq install python3 python3-pip

# Install pandoc filters
RUN pip install pandoc-latex-environment

# Install yq
RUN wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq \
    && chmod +x /usr/bin/yq

# Install git
RUN apt-get -qq install git

#SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Copy entrypoint script
#COPY entrypoint.sh /
#RUN chmod +x /entrypoint.sh

#ENTRYPOINT ["/entrypoint.sh"]
