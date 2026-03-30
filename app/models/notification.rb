class Notification < ApplicationRecord
  belongs_to :user

  validates :notify_type, presence: true
  validates :user_id,     presence: true

  scope :unread,  -> { where(read_at: nil) }
  scope :recent,  -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.zone.now)
  end

  # Human-readable message built from stored params
  def message
    case notify_type
    when 'task_assigned'
      "New task assigned: #{params['task_title']} — Due: #{params['due_date']}"
    when 'task_action'
      "#{params['actor_name']} updated '#{params['task_title']}' to #{params['status']}"
    when 'daily_report'
      "Daily Report ready: #{params['summary']}"
    else
      params['message'].to_s
    end
  end
end
