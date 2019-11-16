
sshpass -p $API_PASSWORD ssh -o StrictHostKeyChecking=no $API_USER@$API_HOST \
  "export PATH && cd $PROJECT_PATH && git pull && ./bin/bundle install && rails runner 'puts ENV[\"RAILS_ENV\"]'"