
sshpass -p $API_PASSWORD ssh -o StrictHostKeyChecking=no $API_USER@$API_HOST \
  "PATH=\"$PATH:/usr/local/rvm/rubies/ruby-2.6.3/bin/\" && \
  echo '111' && \
  echo $PATH && \
  cd $PROJECT_PATH && \
  pwd && \
  ls -la /root && \
  echo '222' && \
  git pull && \
  echo '333' && \
  ./bin/bundle install && \
  echo '444' && \
  ./bin/rails runner 'puts ENV[\"RAILS_ENV\"]'"