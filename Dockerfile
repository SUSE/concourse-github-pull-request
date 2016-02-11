FROM colstrom/alpine

ADD . /opt/concourse-github-pr-resource/

RUN true \
    && apk add --update \
        build-base \
        git \
        libxml2 \
        libxml2-dev \
        libxslt \
        libxslt-dev \
        ruby \
        ruby-bundler \
        ruby-dev \
        ruby-io-console \
        ruby-json \
        zlib \
        zlib-dev \
        openssh \
        openssl \
        ca-certificates \
    && echo "gem: --no-doc" | tee /etc/gemrc \
    && cd /opt/concourse-github-pr-resource \
    && bundle config build.nokogiri --use-system-libraries \
    && bundle install --binstubs=/opt/resource/ --deployment --without=development,test \
    && apk del \
        build-base \
        libxml2-dev \
        libxslt-dev \
        ruby-dev \
        ruby-io-console \
        zlib-dev \
    && rm -rf \
        /opt/concourse-github-pr-resource/vendor/bundle/ruby/2.2.0/cache/ \
        /opt/concourse-github-pr-resource/vendor/bundle/ruby/2.2.0/gems/nokogiri-*/ext/ \
        /var/cache/apk/* \
    && true
