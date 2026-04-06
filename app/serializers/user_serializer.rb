class UserSerializer < ActiveModel::Serializer
  # always included fields
  attributes :id, :name, :role, :active, :phone_number, :mpin_set, :is_admin, :fcm_token, :created_at, :task_counts, :credentials

  attribute :task_stats, if: :include_stats?

  # def task_counts
  #   counts = instance_options[:task_counts] || {}

  #   # counts key is [user_id, status_string]
  #   user_counts = counts.select { |k, _| k[0] == object.id }

  #   pending     = user_counts[[ object.id, 'pending'     ]] || 0
  #   in_progress = user_counts[[ object.id, 'in_progress' ]] || 0
  #   completed   = user_counts[[ object.id, 'completed'   ]] || 0
  #   overdue     = user_counts[[ object.id, 'overdue'     ]] || 0
  #   total       = pending + in_progress + completed + overdue

  #   {
  #     total:       total,
  #     pending:     pending,
  #     in_progress: in_progress,
  #     completed:   completed,
  #     overdue:     overdue
  #   }
  # end

  def task_counts
    if object.admin?
      counts      = instance_options[:admin_task_counts] ||
                    Task.where(created_by: object.id).group(:status).count
      overdue     = instance_options[:admin_overdue_count] ||
                    Task.where(created_by: object.id).overdue.count
      total_users = instance_options[:total_users_count] ||
                    User.where.not(id: object.id).count

      pending     = counts['pending']     || 0
      in_progress = counts['in_progress'] || 0
      completed   = counts['completed']   || 0

      {
        total_users: total_users,
        total_tasks: counts.values.sum,
        completed:   completed,
        pending:     pending,
        in_progress: in_progress,
        overdue:     overdue
      }
    else
      # instance_options[:task_counts] uses composite keys [user_id, status]
      # fallback queries directly for this user with simple status keys
      if instance_options[:task_counts].present?
        raw         = instance_options[:task_counts]
        pending     = raw[[object.id, 'pending']]     || 0
        in_progress = raw[[object.id, 'in_progress']] || 0
        completed   = raw[[object.id, 'completed']]   || 0
      else
        fallback    = Task.where(assigned_to: object.id).group(:status).count
        pending     = fallback['pending']     || 0
        in_progress = fallback['in_progress'] || 0
        completed   = fallback['completed']   || 0
      end

      overdue = if instance_options[:overdue_counts].present?
                  instance_options[:overdue_counts][object.id] || 0
                else
                  Task.where(assigned_to: object.id).overdue.count
                end

      {
        total_tasks: pending + in_progress + completed,
        completed:   completed,
        pending:     pending,
        in_progress: in_progress,
        overdue:     overdue,
        status:      object.active ? 'Active' : 'Inactive'
      }
    end
  end

  def include_stats?
    instance_options[:stats] == true
  end

  def is_admin
    object.admin?
  end

  def credentials
    return nil if object.temp_password.blank?
    {
      phone_number: object.phone_number,
      password:     object.temp_password
    }
  end

end
