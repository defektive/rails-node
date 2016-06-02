FROM instructure/ruby:2.3
MAINTAINER Instructure

USER root

#Install Nginx with Passenger from official repository
RUN  apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 561F9B9CAC40B2F7 \
  && apt-get install -y apt-transport-https ca-certificates \
  && sh -c 'echo deb https://oss-binaries.phusionpassenger.com/apt/passenger trusty main > /etc/apt/sources.list.d/passenger.list' \
  && sh -c 'echo "deb http://apt.postgresql.org/pub/repos/apt/ `lsb_release -cs`-pgdg main" >> /etc/apt/sources.list.d/pgdg.list' \
  && curl --silent https://www.postgresql.org/media/keys/ACCC4CF8.asc | apt-key add - \
  && curl -sL https://deb.nodesource.com/setup_4.x | bash - \
  && apt-get update \
  && apt-get install -y --no-install-recommends nginx-extras passenger postgresql-client-9.5 nodejs \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

RUN echo 'docker ALL=(ALL) NOPASSWD: SETENV: /usr/sbin/nginx' >> /etc/sudoers

#Sensu check
COPY passenger_metrics.rb /monitoring/sensu/
COPY passenger_check /monitoring/sensu/
RUN chmod +x /monitoring/sensu/passenger_metrics.rb /monitoring/sensu/passenger_check

RUN gem install -i /var/lib/gems/$RUBY_MAJOR.0 nokogiri sensu-plugin

USER docker
RUN passenger-config build-native-support \
    && gem install bundler -v '~>1.12' && gem install rails -v '~>4.2'

# Nginx Configuration
USER root

COPY entrypoint /usr/src/entrypoint
COPY nginx.conf.erb /usr/src/nginx/nginx.conf.erb
COPY env-whitelist.conf /usr/src/nginx/main.d/
COPY main.d/* /usr/src/nginx/main.d/
RUN mkdir -p /usr/src/nginx/conf.d \
 && mkdir -p /usr/src/nginx/location.d \
 && mkdir -p /usr/src/nginx/main.d \
 && ln -sf /dev/stdout /var/log/nginx/access.log \
 && ln -sf /dev/stderr /var/log/nginx/error.log \
 && chown docker:docker -R /usr/src/nginx

USER docker

EXPOSE 80
CMD ["/usr/src/entrypoint"]
