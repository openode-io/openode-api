
sshpass -p $API_PASSWORD ssh -o StrictHostKeyChecking=no $API_USER@$API_HOST \
  "PATH=\"$PATH:$RUBY_BIN_PATH\" && \
  cd $PROJECT_PATH && \
  echo 'CWD:' && pwd && \
  echo 'git pulling' && git pull && \
  echo 'bundle install' && ./bin/bundle install && \
  RAILS_ENV=$RAILS_ENV ./bin/rails runner 'puts ENV[\"RAILS_ENV\"]' && \
  RAILS_ENV=$RAILS_ENV ./bin/rails db:migrate && \
  RAILS_ENV=production ./bin/delayed_job --pid-dir=tmp/pids -n 5 restart && \
  pm2 list" # replace with reload