# # config/schedule.rb

set :output, "log/cron.log"
set :environment, "development"

env :PATH, ENV['PATH']


every 30.minute do
  rake "task_reminder:send"
end