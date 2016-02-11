FROM colstrom/alpine

ADD . /opt/concourse-github-pr-resource/

RUN true \
    && apk add --update \
        git \
        ruby \
        ruby-bundler \
        ruby-io-console \
        ruby-json \
        zlib \
        openssh \
        openssl \
        ca-certificates \
    && echo "gem: --no-doc" | tee /etc/gemrc \
    && cd /opt/concourse-github-pr-resource \
    && bundle install --binstubs=/opt/resource/ --deployment --without=development,test \
    && apk del \
        ruby-io-console \
    && rm -rf \
        /opt/concourse-github-pr-resource/vendor/bundle/ruby/2.2.0/cache/ \
        /var/cache/apk/* \
    && true
