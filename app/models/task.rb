class Task < ApplicationRecord
  # creator = person who made the task
  belongs_to :creator,  class_name: 'User', foreign_key: 'created_by'
  # assignee = person who must do the task
  belongs_to :assignee, class_name: 'User', foreign_key: 'assigned_to'

  # status: 0=pending, 1=in_progress, 2=completed, 3=overdue
  enum :status, { pending: 0, in_progress: 1, completed: 2 }

  # priority: 0=low, 1=medium, 2=high, 3=urgent, 4=critical
  enum :priority, { low: 0, medium: 1, high: 2, urgent: 3, critical: 4 }

  validates :title,       presence: true
  validates :assigned_to, presence: true
  validates :created_by,  presence: true

  validates :assign_date,
          presence: true,
          comparison: {
            greater_than_or_equal_to: -> (_) { Date.today },
            message: 'cannot be in the past'
          }, if: -> { new_record? || assign_date_changed? }

  validates :due_date,
          presence: true,
          comparison: {
            greater_than_or_equal_to: -> (_) { Time.zone.now },
            message: 'cannot be in the past'
          }, if: -> { new_record? || due_date_changed? }

  validate :due_date_after_assign_date

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

  # only one custom validate needed — Rails has no cross-field comparison built in
  def due_date_after_assign_date
    return if assign_date.blank? || due_date.blank?
    if due_date.to_date < assign_date.to_date
      errors.add(:due_date, 'must be on or after the assign date')
    end
  end

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
