FROM alpine:3.14 AS buildstage

ENV HOME="/config"

RUN set -eux; \
    apk add \
        build-base \
        git \
        make \
        perl-date-format \
        perl-date-manip \
        perl-datetime \
        perl-datetime-format-strptime \
        perl-dev \
        perl-file-slurp \
        perl-html-tree \
        perl-json \
        perl-json-xs \
        perl-lwp-protocol-https \
        perl-lwp-useragent-determined \
        perl-term-progressbar \
        perl-term-readkey \
        perl-xml-libxml \
        perl-xml-parser \
        perl-xml-treepp  \
        perl-xml-twig \
        perl-xml-writer; \
    wget -qO- https://cpanmin.us | perl - App::cpanminus; \
    `# HTTP::Cache::Transparent is not available in the repositories` \
    `# anyway, using --notest is probably a bad idea` \
    cpanm install --notest HTTP::Cache::Transparent

ARG XMLTV_VER="v1.0.0"
ARG INSTALL_COMPONENTS="tv_grab_na_dtv tv_grab_uk_tvguide tv_grab_combiner"
RUN set -eux; \
    git clone --branch ${XMLTV_VER:-master} https://github.com/XMLTV/xmltv.git /tmp/xmltv; \
    cd /tmp/xmltv; \
    perl Makefile.PL \
        PREFIX=/usr/ \
        INSTALLDIRS=vendor \
        --strict-deps \
        --components="${INSTALL_COMPONENTS}"; \
    make -j $(nproc); \
    make DESTDIR=/tmp/xmltv-build install; \
    mkdir -p /tmp/xmltv-build/usr/local/share/perl5/site_perl/HTTP/Cache; \
    mkdir -p /tmp/xmltv-build/usr/local/lib/perl5/site_perl/auto/HTTP/Cache/Transparent; \
    cp /usr/local/share/perl5/site_perl/HTTP/Cache/Transparent.pm /tmp/xmltv-build/usr/local/share/perl5/site_perl/HTTP/Cache/Transparent.pm; \
    cp /usr/local/lib/perl5/site_perl/auto/HTTP/Cache/Transparent/.packlist /tmp/xmltv-build/usr/local/lib/perl5/site_perl/auto/HTTP/Cache/Transparent/.packlist


FROM alpine:3.14

# environment settings
ENV HOME="/config"

RUN set -eux; \
    apk add --no-cache \
        bash \
        coreutils \
        curl \
        git \
        jq \
        tar; \
    `# Dependencies for XMLTV` \
    apk add --no-cache \
        perl-date-format \
        perl-date-manip \
        perl-datetime \
        perl-datetime-format-strptime \
        perl-file-slurp \
        perl-html-tree \
        perl-json \
        perl-json-xs \
        perl-lwp-protocol-https \
        perl-lwp-useragent-determined \
        perl-term-progressbar \
        perl-term-readkey \
        perl-xml-libxml \
        perl-xml-parser \
        perl-xml-treepp  \
        perl-xml-twig \
        perl-xml-writer; \
    mkdir -p /config/.xmltv; \
    mkdir -p /config/.xmltv/cache; \
    mkdir -p /config/.xmltv/supplement/tv_grab_uk_tvguide

COPY --from=buildstage /tmp/xmltv-build/usr/ /usr/
