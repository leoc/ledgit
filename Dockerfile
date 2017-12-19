FROM ruby:2.3

# Install dependencies
RUN apt-get update -qq && \
    apt-get install -y --no-install-recommends build-essential libpq-dev ledger && \
    rm -rf /var/lib/apt/lists/*

RUN curl -skL https://github.com/odise/go-cron/releases/download/v0.0.6/go-cron-linux.gz | \
    gunzip -c > /root/go-cron && \
    chmod a+x /root/go-cron

ENV APP_ROOT /app
ENV RACK_ENV development
ENV PORT 4040

RUN mkdir -p $APP_ROOT

WORKDIR $APP_ROOT

# Do not install gem documentation
RUN echo 'gem: --no-ri --no-rdoc' > ~/.gemrc

# If we copy the whole app directory, the bundle would install
# everytime an application file changed. Copying the Gemfiles first
# avoids this and installs the bundle only when the Gemfile changed.
COPY Gemfile Gemfile
COPY Gemfile.lock Gemfile.lock
RUN gem install bundler && \
    bundle install --jobs 20 --retry 5

# Now copy the application code to the application directory
COPY . /app

EXPOSE 4040

CMD ["bin/web"]
