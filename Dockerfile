FROM ruby:2.6.3-alpine

ENV PORT=3000
ENV RAILS_ENV=production
ENV RACK_ENV=production
ENV RAILS_ROOT /opt/app

WORKDIR /opt/app

RUN echo 'set -e' > /boot.sh # this is the script which will run on boot

RUN apk add --no-cache build-base \
  tzdata \
  git \
  nodejs \
  mysql-client \
  mariadb-dev

# if you need a build script, uncomment the line below
# RUN echo 'sh mybuild.sh' >> /boot.sh

# daemon for cron jobs
# RUN echo 'echo will install crond...' >> /boot.sh
# RUN echo 'crond' >> /boot.sh
# RUN echo 'crontab .openode.cron' >> /boot.sh

RUN echo 'echo bundle install' >> /boot.sh
RUN echo 'bundle install --jobs 20 --retry 5 --without development test' >> /boot.sh

# todo: migration?

# launch the application
RUN echo 'echo starting the application' >> /boot.sh

CMD sh /boot.sh && rails s
