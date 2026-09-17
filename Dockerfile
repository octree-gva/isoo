FROM ruby:3.4.9

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=C.UTF-8 \
    NODE_MAJOR=20 \
    CHROME_NO_SANDBOX=1

WORKDIR /app

RUN apt-get update && apt-get install -y --no-install-recommends \
    curl wget ripgrep vim \
    && curl -fsSL "https://deb.nodesource.com/setup_${NODE_MAJOR}.x" | bash - \
    && apt-get install -y --no-install-recommends nodejs \
    && wget --quiet --output-document=- https://dl-ssl.google.com/linux/linux_signing_key.pub \
       | gpg --dearmor > /etc/apt/trusted.gpg.d/google-archive.gpg \
    && sh -c 'echo "deb [arch=amd64] http://dl.google.com/linux/chrome/deb/ stable main" \
       >> /etc/apt/sources.list.d/google.list' \
    && apt-get update \
    && apt-get install -y --no-install-recommends google-chrome-stable \
    && npm install -g pm2@6 \
    && rm -rf /var/lib/apt/lists/* /root/.npm

COPY Gemfile Gemfile.lock* ./
RUN bundle install
COPY . .
RUN npm ci && npm run build && rm -rf node_modules
RUN chmod +x bin/docker-entrypoint bin/setup-zitadel-oidc bin/setup-zitadel-smtp
EXPOSE 9292
ENTRYPOINT ["bin/docker-entrypoint"]
CMD ["pm2-runtime", "start", "ecosystem.config.cjs"]
