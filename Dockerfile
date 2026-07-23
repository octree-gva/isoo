FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    RUBY_VERSION=3.4.9 \
    NODE_MAJOR=20 \
    CHROME_NO_SANDBOX=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    ca-certificates curl git gnupg wget \
    build-essential autoconf bison \
    libssl-dev libyaml-dev libreadline-dev zlib1g-dev \
    libncurses-dev libffi-dev libgdbm-dev \
    && curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && wget --quiet --output-document=- https://dl-ssl.google.com/linux/linux_signing_key.pub \
       | gpg --dearmor > /etc/apt/trusted.gpg.d/google-archive.gpg \
    && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" \
       >> /etc/apt/sources.list.d/google.list' \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-chrome-stable \
    && curl -fsSL "https://github.com/rbenv/ruby-build/archive/refs/tags/v20260716.tar.gz" \
       | tar -xz -C /tmp \
    && /tmp/ruby-build-*/bin/ruby-build "${RUBY_VERSION}" /usr/local \
    && rm -rf /tmp/ruby-build-* \
    && gem install bundler --no-document \
    && npm install -g pm2@6 \
    && rm -rf /var/lib/apt/lists/* /root/.npm /usr/local/share/ruby-build

COPY Gemfile Gemfile.lock* ./
RUN bundle install
COPY . .
RUN npm ci && npm run build && rm -rf node_modules
RUN chmod +x bin/docker-entrypoint bin/setup-zitadel-oidc bin/setup-zitadel-smtp
EXPOSE 9292
ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["pm2-runtime", "start", "ecosystem.config.cjs"]
