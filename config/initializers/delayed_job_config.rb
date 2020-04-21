
Delayed::Worker.max_run_time = Deployment::MAX_RUN_TIME
Delayed::Worker.max_attempts = 3
Delayed::Worker.logger = Logger.new(Rails.root.join('log/delayed_job.log'))
