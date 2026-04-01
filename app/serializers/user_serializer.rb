class UserSerializer < ActiveModel::Serializer
  # always included fields
  attributes :id, :name, :role, :active, :phone_number, :mpin_set, :is_admin, :fcm_token, :created_at, :task_counts

  attribute :task_stats, if: :include_stats?

  def task_counts
    counts = instance_options[:task_counts] || {}

    # counts key is [user_id, status_string]
    user_counts = counts.select { |k, _| k[0] == object.id }

    pending     = user_counts[[ object.id, 'pending'     ]] || 0
    in_progress = user_counts[[ object.id, 'in_progress' ]] || 0
    completed   = user_counts[[ object.id, 'completed'   ]] || 0
    overdue     = user_counts[[ object.id, 'overdue'     ]] || 0
    total       = pending + in_progress + completed + overdue

    {
      total:       total,
      pending:     pending,
      in_progress: in_progress,
      completed:   completed,
      overdue:     overdue
    }
  end

  def include_stats?
    instance_options[:stats] == true
  end

  def is_admin
    object.admin?
  end
end
