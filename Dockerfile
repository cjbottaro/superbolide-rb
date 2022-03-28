FROM 853401350379.dkr.ecr.us-east-1.amazonaws.com/ruby:2.6.6-alpine3.12

RUN apk add --no-cache build-base git

RUN gem uninstall bundler
RUN gem install --no-document bundler
RUN bundle config silence_root_warning true

WORKDIR /app

ADD Gemfile Gemfile.lock superbolide.gemspec ./
RUN bundle install --deployment --jobs 16

ADD . .

ENTRYPOINT ["bundle", "exec"]