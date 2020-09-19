
echo "Soft reloading..."
echo "Environment: "
echo $RAILS_ENV

until ./bin/rails runner "raise 'busy' unless System::Global.queues_len.zero? "
do
        echo "waiting..."
        sleep 5
done

pm2 reload sidekiq
pm2 reload openode-api
