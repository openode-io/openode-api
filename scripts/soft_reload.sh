
echo "Soft reloading..."
echo "Environment: "
echo $RAILS_ENV

until ./bin/rails runner "raise \"busy!\" unless Delayed::Job.count.zero? "
do
        echo "waiting..."
        sleep 5
done

pm2 reload openode-job
pm2 reload openode-api
