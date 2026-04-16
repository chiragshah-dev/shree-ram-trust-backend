# # config/schedule.rb


set :output, "/home/developer/projects/shree-ram-trust-backend/log/cron.log"
set :environment, "development"
set :job_template, "/bin/bash -l -c 'source /home/developer/.rvm/scripts/rvm && rvm use 3.2.2@shreeram && export RUBYOPT=\"-W0\" && :job'"

every 30.minute do
  rake "task_reminder:send"
end

every 1.day, at: "12:00 am" do
  rake "notification_cleanup:delete_old"
end