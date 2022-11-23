# https://github.com/CharleneMcKeown/github-runner-aci
FROM mcr.microsoft.com/powershell

# Install requirements
ARG DEBIAN_FRONTEND=noninteractive
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       wget \
       curl \
       perl-tk \
       git \
       fonts-noto-cjk \
       fonts-crosextra-carlito \
       librsvg2-bin \
       python3 \
       python3-pip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /rootbase

# Download the latest TeX Live installer
RUN curl -L -O http://mirror.ctan.org/systems/texlive/tlnet/install-tl-unx.tar.gz \
    && mkdir /rootbase/install-tl \
    && tar xzf install-tl-unx.tar.gz --strip-components 1 -C "/rootbase/install-tl" \
    && rm install-tl-unx.tar.gz

WORKDIR install-tl

COPY texlive-profile.txt /rootbase/install-tl

# Install TeX Live
RUN /rootbase/install-tl/install-tl --profile=/rootbase/install-tl/texlive-profile.txt

WORKDIR /

RUN rm -rf /rootbase

ENV PATH="${PATH}:/usr/local/texlive/bin/x86_64-linux:/usr/local/bin"

# Install TeX Live packages
RUN tlmgr install \
    adjustbox \
##    amsfonts \
##    amsmath \
    anysize \
    awesomebox \
##    babel \
    background \
    beamer \
    biblatex \
    bidi \
##    bookmark \
    booktabs \
    breqn \
    caption \
    catchfile \
    cite \
    collectbox \
    crop \
    csquotes \
    ctable \
    enumitem \
    environ \
    eso-pic \
    everypage \
    etoolbox \
    extsizes \
    fancybox \
##    fancyhdr \
    fancyref \
    fancyvrb \
    fontawesome5 \
    footmisc \
    footnotebackref \
    footnotehyper \
    fvextra \
##    geometry \
    hardwrap \
##    hyperref \
##    iftex \
    index \
    jknapltx \
    koma-script \
    l3experimental \
    lastpage \
    latexbug \
    lineno \
    listings \
##    lm \
    lwarp \
    luatexja \
    ly1 \
    mathspec \
    mathtools \
    mdframed \
    mdwtools \
    metalogo \
    microtype \
    multirow \
    mweights \
##    natbib \
    needspace \
    ntgclass \
    pagecolor \
    parskip \
    pdfpages \
    pgf \
    powerdot \
    psfrag \
    rcs \
    sansmath \
    section \
    sectsty \
    selnolig \
    seminar \
    sepnum \
    setspace \
    sourcecodepro \
    sourcesanspro \
    tcolorbox \
    textcase \
    thumbpdf \
    titling \
    tools \
    trimspaces \
    typehtml \
    ucharcat \
    ulem \
    underscore \
    unicode-math \
    upquote \
    xecjk \
    xcolor \
    xltxtra \
    xurl \
    zref

# Install pandoc
RUN wget -qO- "https://github.com/jgm/pandoc/releases/download/2.19.2/pandoc-2.19.2-linux-amd64.tar.gz" | tar xzf - --strip-components 1 -C "/usr/local/"

# Install pandoc filters
RUN pip install pandoc-latex-environment

# Install yq
RUN wget -q https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64 -O /usr/bin/yq \
    && chmod +x /usr/bin/yq

#SHELL ["pwsh", "-Command", "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';"]

# Copy entrypoint script
#COPY entrypoint.sh /
#RUN chmod +x /entrypoint.sh

#ENTRYPOINT ["/entrypoint.sh"]
