FROM node:12-alpine

WORKDIR /opt/app

ENV PORT=80

# Extras:

# Globally installed NPMs:

RUN echo 'set -e' > /boot.sh # this is the script which will run on start

# Basic npm start verification

# daemon for cron jobs
RUN echo 'echo will install crond...' >> /boot.sh
# RUN echo 'crond' >> /boot.sh

# install packages
COPY package*.json ./
RUN npm install --production

# Bundle app source
COPY . .

# logs by default are in logs
RUN mkdir -p logs

# npm start, make sure to have a start attribute in "scripts" in package.json
CMD sh /boot.sh && npm start