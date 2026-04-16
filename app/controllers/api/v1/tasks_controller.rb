class Api::V1::TasksController < Api::V1::BaseController
  before_action :admin_only!, only: [:create, :update, :destroy]
  before_action :set_task,    only: [:show, :update, :destroy, :complete, :update_status]

  # GET /api/v1/tasks/dashboard
  def dashboard
    base = task_scope

    # single GROUP BY query for stored status counts
    counts      = base.group(:status).count
    total       = counts.values.sum
    pending     = counts['pending']     || 0
    in_progress = counts['in_progress'] || 0
    completed   = counts['completed']   || 0

    # overdue is a SCOPE (due_date < now AND not completed) — not a stored status
    overdue = base.overdue.count

    # progress percentage
    progress_percentage = total > 0 ? ((completed.to_f / total) * 100).round(2) : 0

    # current user info — no extra query, already loaded from JWT
    user_info = {
      id:              current_user.id,
      name:            current_user.name,
      role:            current_user.role
    }

    if current_user.admin?
      render_success({
        user:  user_info,
        stats: {
          total_tasks:       total,
          pending_tasks:     pending,
          completed_tasks:   completed,
          in_progress_tasks: in_progress,
          overdue_tasks:     overdue,
          total_users:       User.where(role: :user).count
        },
        recent_tasks: serialize(
          base.includes(:creator, :assignee)
              .order(created_at: :desc)
              .limit(10),
          each_serializer: TaskSerializer
        )
      }, message: 'Dashboard fetched successfully')

    else
      render_success({
        user: user_info,
        overall_progress: {
          percentage:      progress_percentage,
          completed_tasks: completed,
          total_tasks:     total,
          label:           "#{completed} of #{total} tasks completed"
        },
        stats: {
          total:       total,
          pending:     pending,
          completed:   completed,
          in_progress: in_progress,
          overdue:     overdue
        },
        recent_tasks: serialize(
          base.includes(:creator, :assignee)
              .order(created_at: :desc)
              .limit(10),
          each_serializer: TaskSerializer
        ),
        today:    serialize(
          base.today.includes(:creator, :assignee),
          each_serializer: TaskSerializer
        ),
        upcoming: serialize(
          base.upcoming.includes(:creator, :assignee).limit(20),
          each_serializer: TaskSerializer
        ),
        overdue:  serialize(
          base.overdue.includes(:creator, :assignee),
          each_serializer: TaskSerializer
        )
      }, message: 'Dashboard fetched successfully')
    end
  end

  # GET /api/v1/tasks
  def index
    tasks = task_scope
              .includes(:creator, :assignee)
              .order(created_at: :desc)

    # filters
    tasks = tasks.where(status:      params[:status])            if params[:status].present?
    tasks = tasks.where(priority:    params[:priority])          if params[:priority].present?
    tasks = tasks.where(assigned_to: params[:assigned_to])       if params[:assigned_to].present?
    tasks = tasks.where('due_date >= ?', params[:from])          if params[:from].present?
    tasks = tasks.where('due_date <= ?', params[:to])            if params[:to].present?
    tasks = tasks.where('title ILIKE ?', "%#{params[:search]}%") if params[:search].present?

    # validate enum filters before hitting DB to avoid ArgumentError
    if params[:status].present? && !Task.statuses.key?(params[:status])
      return render_error(
        "Invalid status. Use: #{Task.statuses.keys.join(', ')}",
        :unprocessable_entity
      )
    end

    if params[:priority].present? && !Task.priorities.key?(params[:priority])
      return render_error(
        "Invalid priority. Use: #{Task.priorities.keys.join(', ')}",
        :unprocessable_entity
      )
    end

    tasks = tasks.page(params[:page]).per(params[:per_page] || 10)

    render_list(
      serialize(tasks, each_serializer: TaskSerializer),
      meta: pagination_meta(tasks)
    )
  rescue ArgumentError => e
    render_error(e.message, :unprocessable_entity)
  end

  # GET /api/v1/tasks/:id
  def show
    # normal user cannot view someone else's task
    unless current_user.admin? || @task.assigned_to == current_user.id
      return render_error('Access denied. This task is not assigned to you.', :forbidden)
    end
    render_success(serialize(@task, serializer: TaskSerializer))
  end

  # POST /api/v1/tasks — admin only
  def create
    if task_params[:assigned_to].to_i == current_user.id
      return render_error('Admin cannot assign task to themselves.', :forbidden)
    end

    # validate priority
    if task_params[:priority].present? && !Task.priorities.key?(task_params[:priority])
      return render_error(
        "Invalid priority. Use: #{Task.priorities.keys.join(', ')}",
        :unprocessable_entity
      )
    end

    task = Task.new(task_params.merge(created_by: current_user.id))

    if task.save
      task.voice_note.attach(params[:task][:voice_note]) if params[:task][:voice_note]
      render_success(
        serialize(task, serializer: TaskSerializer),
        message: 'Task created successfully.',
        status:  :created
      )
      notify_assignee_on_create(task)
    else
      render_validation_error(task)
    end
  rescue ArgumentError => e
    render_error(e.message, :unprocessable_entity)
  rescue ActionController::ParameterMissing => e
    render_error(e.message, :unprocessable_entity)
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.join(', '), :unprocessable_entity)
  rescue StandardError => e
    Rails.logger.error("Task Create Error: #{e.message}")
    render_error('Something went wrong', :internal_server_error)
  end

  # PATCH /api/v1/tasks/:id — admin only
  def update
    if task_params.present? && task_params[:assigned_to].to_i == current_user.id
      return render_error('Admin cannot assign task to themselves.', :forbidden)
    end
    # validate priority
    if  task_params.present? && task_params[:priority].present? && !Task.priorities.key?(task_params[:priority])
      return render_error(
        "Invalid priority. Use: #{Task.priorities.keys.join(', ')}",
        :unprocessable_entity
      )
    end

    if @task.update(task_params)
      if params[:task][:voice_note]
        @task.voice_note.attach(params[:task][:voice_note])
      end
      render_success(serialize(@task, serializer: TaskSerializer),
                     message: 'Task updated successfully')
    else
      render_validation_error(@task)
    end
  rescue ArgumentError => e
    render_error(e.message, :unprocessable_entity)
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.join(', '), :unprocessable_entity)
  rescue StandardError => e
    Rails.logger.error("Task Update Error: #{e.message}")
    render_error('Something went wrong', :internal_server_error)
  end

  # PATCH /api/v1/tasks/:id/update_status — assigned user only
  def update_status
    # block admin from updating status
    if current_user.admin?
      return render_error('Admin cannot update task status. Only the assigned user can.', :forbidden)
    end

    # block user from updating someone else's task
    unless @task.assigned_to == current_user.id
      return render_error('You can only update status of your own assigned tasks.', :forbidden)
    end

    new_status = params.dig(:task, :status)

    return render_error('Status is required.', :unprocessable_entity) if new_status.blank?

    unless Task.statuses.key?(new_status)
      return render_error(
        "Invalid status. Use: #{Task.statuses.keys.join(', ')}",
        :unprocessable_entity
      )
    end

    if @task.completed?
      return render_error('Completed tasks cannot be changed.', :unprocessable_entity)
    end

    old_status = @task.status
    @task.update_column(:status, new_status)
    notify_admins_on_action(@task, current_user, new_status, old_status: old_status)

    render_success(serialize(@task, serializer: TaskSerializer),
                   message: "Task status updated to #{new_status.humanize}")
  end

  # PATCH /api/v1/tasks/:id/complete — assigned user only
  def complete
    if current_user.admin?
      return render_error('Admin cannot complete tasks. Only the assigned user can.', :forbidden)
    end

    unless @task.assigned_to == current_user.id
      return render_error('You can only complete your own assigned tasks.', :forbidden)
    end

    if @task.completed?
      return render_error('Task is already completed.', :unprocessable_entity)
    end

    @task.update_column(:status, "completed")
    notify_admins_on_action(@task, current_user, 'completed')

    render_success(serialize(@task, serializer: TaskSerializer),
                   message: 'Task marked as completed')
  end

  # DELETE /api/v1/tasks/:id — admin only
  def destroy
    @task.destroy!
    render_success(nil, message: 'Task deleted successfully')
  end

  private

  def set_task
    @task = Task.includes(:creator, :assignee).find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('Task not found', :not_found)
  end

  def task_scope
    current_user.admin? ? Task.all : Task.where(assigned_to: current_user.id)
  end

   # Notify assignee when a new task is created — called in create
  def notify_assignee_on_create(task)
    assignee = task.assignee
    return unless assignee
    due = task.due_date.strftime('%d %b %Y, %I:%M %p')

    Notification.create!(
      user_id:     assignee.id,
      notify_type: 'task_assigned',
      params: {
        'task_id'    => task.id,
        'task_title' => task.title,
        'due_date'   => task.due_date.to_s,
        'created_by' => current_user.name,
        'message'    => "#{current_user.name} assigned you a new task: #{task.title} — Due: #{due}"
      }
    )
    FcmService.send_notification(
      fcm_token: assignee.device_id,
      title:     'New Task Assigned',
      body:      "#{current_user.name} assigned you a new task: #{task.title} — Due: #{due}",
      data: {
        'type'       => 'task_assigned',
        'task_id'    => task.id.to_s,
        'task_title' => task.title,
        'due_date'   => task.due_date.to_s,
        'created_by' => current_user.name
      }
    )
  end

  # Notify all admins when user updates/completes a task — called in update_status & complete
  def notify_admins_on_action(task, actor, new_status, old_status: nil)
    User.where(role: :admin).each do |admin|
      Notification.create!(
        user_id:     admin.id,
        notify_type: 'task_action',
        params: {
          'task_id'    => task.id,
          'task_title' => task.title,
          'new_status' => new_status,
          'old_status' => old_status,
          'actor_name' => actor.name,
          'actor_id'   => actor.id,
          'message'    => "#{actor.name} changed #{task.title} Task to #{new_status.humanize}"
        }
      )

      FcmService.send_notification(
        fcm_token: admin.device_id,
        title:     'Task Status Updated',
        body:      "#{actor.name} user changed #{task.title} Task to #{new_status.humanize}",
        data: {
          'type'       => 'task_action',
          'task_id'    => task.id.to_s,
          'task_title' => task.title,
          'new_status' => new_status,
          'old_status' => old_status.to_s,
          'actor_name' => actor.name,
          'actor_id'   => actor.id.to_s
        }
      )
    end
  end

  def task_params
    params.require(:task).permit(
      :title,
      :description,
      :notes,
      :priority,
      :due_date,
      :assigned_to,
      :voice_note
    )
  end
end
