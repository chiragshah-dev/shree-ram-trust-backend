class UserSerializer < ActiveModel::Serializer
  # always included fields
  attributes :id, :name, :email, :role, :active, :is_admin, :fcm_token, :created_at

  attribute :task_stats, if: :include_stats?

  def task_stats
    {
      total:       object.assigned_tasks.count,
      completed:   object.assigned_tasks.completed.count,
      pending:     object.assigned_tasks.pending.count,
      overdue:     object.assigned_tasks.overdue.count,
      in_progress: object.assigned_tasks.in_progress.count
    }
  end

  def include_stats?
    instance_options[:stats] == true
  end

  def is_admin
    object.admin?
  end
end
