# lib/tasks/task_reminder.rake
namespace :task_reminder do
  desc "Send task due reminders"
  task send: :environment do
      TaskReminderService.call
  end
end
