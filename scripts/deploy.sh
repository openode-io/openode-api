
sshpass -p $API_PASSWORD ssh -o StrictHostKeyChecking=no $API_USER@$API_HOST \
  "source /root/.bashrc && \
  echo '111' && \
  echo $PATH && \
  which ruby && \
  cd $PROJECT_PATH && \
  echo '222' && \
  git pull && \
  echo '333' && \
  ./bin/bundle install && \
  echo '444' && \
  ./bin/rails runner 'puts ENV[\"RAILS_ENV\"]'"