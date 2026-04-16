# app/services/task_reminder_service.rb
class TaskReminderService
  def self.call
    now = Time.zone.now

    # If running every 1 hour, look back 1 hour + 5 mins safety buffer
    buffer = 1.hour + 5.minutes

    #  pass the 'time_diff' as the last argument so the service knows if it's a 3h or 1h reminder
    send_reminders(now + 1.hour, now + 3.hours, :notified_3h, "task_due_3h", 3.hours)
    send_reminders(now - buffer, now + 1.hour, :notified_1h, "task_due_1h", 1.hour)
  end


  
  def self.send_reminders(start_range, end_range, column, notify_type, time_diff)
    # Range search prevents double notifications
    tasks = Task.pending.where(due_date: start_range..end_range)
                .where(column => [false, nil])

    tasks.find_each do |task|
      user = task.assignee
      next unless user

      due = task.due_date.strftime("%d %b %Y, %I:%M %p")

      Notification.create!(
        user_id: user.id,
        notify_type: notify_type,
        params: {
          task_id: task.id,
          task_title: task.title,
          due_date: task.due_date,
          message: message_for(time_diff),
        },
      )

      if user.device_id.present?
        FcmService.send_notification(
          fcm_token: user.device_id,
          title: task.title,
          body: message_for(time_diff),
          data: {
            "type" => notify_type,
            "task_id" => task.id.to_s,
            "task_title" => task.title,
            "due_date" => task.due_date.to_s,
          },
        )
      end

      task.update_column(column, true)
    end
  end

  def self.message_for(time_diff)
    case time_diff
    when 3.hours then "Task is due in 3 hours"
    when 1.hour then "Task is due in 1 hour"
    else "Task is due soon"
    end
  end
end
