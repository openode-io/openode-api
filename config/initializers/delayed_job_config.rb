
Delayed::Worker.max_run_time = 20.minutes
Delayed::Worker.max_attempts = 3
Delayed::Worker.logger = Logger.new(Rails.root.join('log', 'delayed_job.log'))
