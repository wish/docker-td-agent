FROM debian:stretch-slim
LABEL maintainer "TAGOMORI Satoshi <tagomoris@gmail.com>"
LABEL Description="Fluentd docker image" Vendor="Fluent Organization" Version="1.1"

ENV DUMB_INIT_VERSION=1.2.1

ENV GOSU_VERSION=1.10

ARG DEBIAN_FRONTEND=noninteractive

# Do not split this into multiple RUN!
# Docker creates a layer for every RUN-Statement
# therefore an 'apt-get purge' has no effect
RUN apt-get update \
 && apt-get upgrade -y \
 && apt-get install -y --no-install-recommends \
            ca-certificates \
            ruby \
 && buildDeps=" \
      make gcc g++ libc-dev \
      ruby-dev \
      wget bzip2 gnupg dirmngr \
    " \
 && apt-get install -y --no-install-recommends $buildDeps \
 && update-ca-certificates \
 && echo 'gem: --no-document' >> /etc/gemrc \
 && gem install oj -v 3.3.10 \
 && gem install json -v 2.1.0 \
 && gem install fluentd -v 1.2.2 \
 && dpkgArch="$(dpkg --print-architecture | awk -F- '{ print $NF }')" \
 && wget -O /usr/bin/dumb-init https://github.com/Yelp/dumb-init/releases/download/v${DUMB_INIT_VERSION}/dumb-init_${DUMB_INIT_VERSION}_$dpkgArch \
 && chmod +x /usr/bin/dumb-init \
 && wget -O /usr/local/bin/gosu "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch" \
 && wget -O /usr/local/bin/gosu.asc "https://github.com/tianon/gosu/releases/download/$GOSU_VERSION/gosu-$dpkgArch.asc" \
 && export GNUPGHOME="$(mktemp -d)" \
 && gpg --keyserver hkp://p80.pool.sks-keyservers.net:80 --recv-keys B42F6819007F00F88E364FD4036A9C25BF357DD4 \
 && gpg --batch --verify /usr/local/bin/gosu.asc /usr/local/bin/gosu \
 && rm -rf "$GNUPGHOME" /usr/local/bin/gosu.asc \
 && chmod +x /usr/local/bin/gosu \
 && gosu nobody true \
 && wget -O /tmp/jemalloc-4.5.0.tar.bz2 https://github.com/jemalloc/jemalloc/releases/download/4.5.0/jemalloc-4.5.0.tar.bz2 \
 && cd /tmp && tar -xjf jemalloc-4.5.0.tar.bz2 && cd jemalloc-4.5.0/ \
 && ./configure && make \
 && mv lib/libjemalloc.so.2 /usr/lib \
 && apt-get purge -y --auto-remove \
                  -o APT::AutoRemove::RecommendsImportant=false \
                  $buildDeps \
 && rm -rf /var/lib/apt/lists/* \
 && rm -rf /tmp/* /var/tmp/* /usr/lib/ruby/gems/*/cache/*.gem

RUN buildDeps="sudo make gcc g++ libc-dev ruby-dev" \
 && apt-get update \
 && apt-get install -y --no-install-recommends $buildDeps \
 && sudo gem install \
        fluent-config-regexp-type \
        fluent-logger \
        fluent-plugin-copy_ex \
        fluent-plugin-elasticsearch \
        fluent-plugin-kafka \
        fluent-plugin-kinesis \
        fluent-plugin-record-modifier \
        fluent-plugin-rewrite-tag-filter \
        fluent-plugin-s3 \
        fluent-plugin-td \
        fluent-plugin-td-monitoring \
        fluent-plugin-webhdfs \
 && gem install fluent-plugin-prometheus -v 1.0.1 \
 && sudo gem sources --clear-all \
 && SUDO_FORCE_REMOVE=yes \
    apt-get purge -y --auto-remove \
                  -o APT::AutoRemove::RecommendsImportant=false \
                  $buildDeps \
 && rm -rf /var/lib/apt/lists/* \
           /home/fluent/.gem/ruby/2.3.0/cache/*.gem

# for log storage (maybe shared with host)
RUN mkdir -p /fluentd/log
# configuration/plugins path (default: copied from .)
RUN mkdir -p /fluentd/etc /fluentd/plugins

COPY fluent.conf /fluentd/etc/
COPY entrypoint.sh /bin/
RUN chmod +x /bin/entrypoint.sh


ENV FLUENTD_OPT=""
ENV FLUENTD_CONF="fluent.conf"

ENV LD_PRELOAD="/usr/lib/libjemalloc.so.2"
ENV DUMB_INIT_SETSID 0

EXPOSE 24224 5140

ENTRYPOINT ["/bin/entrypoint.sh"]

CMD exec fluentd -c /fluentd/etc/${FLUENTD_CONF} -p /fluentd/plugins $FLUENTD_OPT
