set -e

echo $SERVER_PK_KEY | base64 --decode > id_rsa_tmp
chmod 400 id_rsa_tmp

ssh -i id_rsa_tmp -o StrictHostKeyChecking=no $SERVER_USER@$SERVER_HOST  \
  "PATH=\"$PATH:$RUBY_BIN_PATH:$NODE_BIN_PATH\" && \
  cd $PROJECT_PATH && \
  echo 'CWD:' && pwd && \
  echo 'git pulling' && git pull && \
  echo 'bundle install' && bundle install && \
  RAILS_ENV=$RAILS_ENV ./bin/rails runner 'puts ENV[\"RAILS_ENV\"]' && \
  RAILS_ENV=$RAILS_ENV ./bin/rails db:migrate && \
  RAILS_ENV=$RAILS_ENV bash scripts/soft_reload.sh && \
  pm2 list && \
  ps aux | grep sidekiq"

ssh -i id_rsa_tmp -o StrictHostKeyChecking=no $SERVER_USER@$SERVER_HOST \
  "cd $PROJECT_PATH && cat scripts/crontab.txt | crontab -"

rm -f id_rsa_tmp

# deploy a test site
cd scripts/test-prod

sleep 15

openode ci-conf $OPENODE_TOKEN $OPENODE_SITE_NAME
pwd
ls -la
openode deploy
sleep 2
openode stop