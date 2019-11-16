

sshpass -p $API_PASSWORD ssh -o StrictHostKeyChecking=no $API_USER@$API_HOST "date && pm2 list"