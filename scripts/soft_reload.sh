
echo "Soft reloading..."
echo "Environment: "
echo $RAILS_ENV

until ./bin/rails runner "raise 'busy' unless System::Global.queues_len.zero? "
do
        echo "waiting..."
        sleep 5
done

/usr/local/bin/pm2 reload sidekiq
/usr/local/bin/pm2 reload openode-api
