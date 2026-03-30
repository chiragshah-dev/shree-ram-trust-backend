class Task < ApplicationRecord
  # creator = person who made the task
  belongs_to :creator,  class_name: 'User', foreign_key: 'created_by'
  # assignee = person who must do the task
  belongs_to :assignee, class_name: 'User', foreign_key: 'assigned_to'

  # status: 0=pending, 1=in_progress, 2=completed, 3=overdue
  enum :status, { pending: 0, in_progress: 1, completed: 2, overdue: 3 }

  validates :title,       presence: true
  validates :assign_date, presence: true
  validates :due_date,    presence: true
  validates :assigned_to, presence: true
  validates :created_by,  presence: true

  # Scopes — reusable query shortcuts
  scope :today,    -> { where(due_date: Time.zone.now.beginning_of_day..Time.zone.now.end_of_day) }
  scope :upcoming, -> { where('due_date > ?', Time.zone.now.end_of_day) }
  scope :overdue,  -> {
    where('due_date < ? AND status NOT IN (?)',
          Time.zone.now,
          [Task.statuses[:completed]])
  }

  # Automatically send notification when task is created
  # after_create  :notify_assignee_on_create
  # Automatically notify admin when status changes
  # after_update  :notify_admin_on_action, if: :saved_change_to_status?

  private

  def notify_assignee_on_create
    Notification.create!(
      user_id:     assigned_to,
      notify_type: 'task_assigned',
      params: {
        'task_id'    => id,
        'task_title' => title,
        'due_date'   => due_date.to_s,
        'created_by' => creator&.name
      }
    )
  end

  def notify_admin_on_action
    User.where(role: :admin).each do |admin|
      Notification.create!(
        user_id:     admin.id,
        notify_type: 'task_action',
        params: {
          'task_id'    => id,
          'task_title' => title,
          'status'     => status,
          'actor_name' => assignee&.name
        }
      )
    end
  end
end
