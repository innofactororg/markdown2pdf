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
