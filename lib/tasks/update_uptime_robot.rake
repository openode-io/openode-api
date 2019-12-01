require 'uptimerobot'

# 0 - paused
# 1 - not checked yet
# 2 - up
# 8 - seems down
# 9 - down

def stringify_status(status_code)
  case status_code
  when 0
    'paused'
  when 1
    'not_checked_yet'
  when 2
    'up'
  when 8
    'seems_down'
  when 9
    'down'
  else
    'unknown'
  end
end

namespace :update do
  desc ''
  task uptime_robot: :environment do
    task_name = "Task update:uptime_robot"
    Rails.logger.info "[#{task_name}] begin"

    client = UptimeRobot::Client.new(api_key: ENV['UPTIME_ROBOT_API_KEY'])
    monitors_result = client.getMonitors

    puts "monitor res #{monitors_result.inspect}"

    monitors_result['monitors'].each do |monitor|
      puts "looping"
      name = monitor['friendly_name']
      status = stringify_status(monitor['status'])

      if Status.exists? name: name
        Rails.logger.info "[#{task_name}] Updating status #{name} to status #{status}"
        status_record = Status.find_by name: name
        status_record.status = status
        status_record.save
      else
        Rails.logger.info "[#{task_name}] Creating status #{name} to status #{status}"

        Status.create(name: name, status: status)
      end
    end
  end
end
