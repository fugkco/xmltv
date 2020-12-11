FROM alpine:3.12 AS buildstage

ENV HOME="/config"

ARG XMLTV_VER="v0.6.3"
ARG INSTALL_COMPONENTS="tv_grab_na_dtv tv_grab_uk_tvguide tv_grab_combiner"
RUN set -eux; \
    apk add \
        build-base \
        make \
        git \
        perl-dev \
        perl-datetime \
        perl-date-format \
        perl-date-manip \
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
    cpanm install --notest HTTP::Cache::Transparent; \

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


FROM alpine:3.12

# environment settings
ENV HOME="/config"

RUN set -eux; \
    apk add --no-cache git; \

    apk add --no-cache \
        `# Dependencies for XMLTV` \
        perl-datetime \
        perl-date-format \
        perl-date-manip \
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

    mkdir -p $HOME/.xmltv

COPY --from=buildstage /tmp/xmltv-build/usr/ /usr/
