
sshpass -p $API_PASSWORD ssh -o StrictHostKeyChecking=no $API_USER@$API_HOST \
  "PATH=\"$PATH:$RUBY_BIN_PATH\" && \
  cd $PROJECT_PATH && \
  echo 'CWD:' && pwd && \
  echo 'git pulling' && git pull && \
  echo 'bundle install' && ./bin/bundle install && \
  RAILS_ENV=$RAILS_ENV ./bin/rails runner 'puts ENV[\"RAILS_ENV\"]' && \
  RAILS_ENV=$RAILS_ENV ./bin/rails db:migrate && \
  pm2 reload openode_jobs && \
  pm2 list" # replace with reload