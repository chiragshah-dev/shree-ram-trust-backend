namespace :notification_cleanup do
  desc "Delete notifications older than 3 days"
  task delete_old: :environment do
    cutoff_time = 3.days.ago

    deleted_count = Notification.where("created_at < ?", cutoff_time).destroy_all

    puts "Deleted #{deleted_count} old notifications (older than 3 days)"
  end
end