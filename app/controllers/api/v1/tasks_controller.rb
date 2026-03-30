class Api::V1::TasksController < Api::V1::BaseController
  before_action :admin_only!, only: [:create, :destroy]
  before_action :set_task, only: [:show, :update, :destroy, :complete, :update_status]

  # GET /api/v1/tasks/dashboard
  def dashboard
    base = task_scope

    render_success({
      stats: {
        total:       base.count,
        completed:   base.completed.count,
        pending:     base.pending.count,
        in_progress: base.in_progress.count,
        overdue:     base.overdue.count
      },
      today:    serialize(base.today.includes(:creator, :assignee),
                          each_serializer: TaskSerializer),
      upcoming: serialize(base.upcoming.includes(:creator, :assignee).limit(20),
                          each_serializer: TaskSerializer),
      overdue:  serialize(base.overdue.includes(:creator, :assignee),
                          each_serializer: TaskSerializer)
    }, message: 'Dashboard fetched successfully')
  end

  # GET /api/v1/tasks
  def index
    tasks = task_scope.includes(:creator, :assignee)
    tasks = tasks.where(status: params[:status])                          if params[:status].present?
    tasks = tasks.where(assigned_to: params[:assigned_to])               if params[:assigned_to].present?
    tasks = tasks.where('due_date >= ?', params[:from])                  if params[:from].present?
    tasks = tasks.where('due_date <= ?', params[:to])                    if params[:to].present?
    tasks = tasks.where('title ILIKE ?', "%#{params[:search]}%")         if params[:search].present?
    tasks = tasks.order(due_date: :asc).page(params[:page]).per(10)

    render_list(
      serialize(tasks, each_serializer: TaskSerializer),
      meta: pagination_meta(tasks)
    )
  end

  # GET /api/v1/tasks/:id
  def show
    render_success(serialize(@task, serializer: TaskSerializer))
  end

  # POST /api/v1/tasks  — admin only (before_action handles this)
  def create
    task = Task.new(task_params.merge(created_by: current_user.id))
    if task.save
      render_success(serialize(task, serializer: TaskSerializer),
                     message: 'Task created. Assignee notified.',
                     status: :created)
    else
      render_validation_error(task)
    end
  rescue ActionController::ParameterMissing => e
    render_error(e.message, :unprocessable_entity)
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.join(', '), :unprocessable_entity)
  rescue StandardError => e
    Rails.logger.error("Task Create Error: #{e.message}")
    render_error('Something went wrong', :internal_server_error)
  end

  # PATCH /api/v1/tasks/:id  — admin only (edit title/description/dates/assignee)
  def update
    return render_error('Access denied. Admin only.', :forbidden) unless current_user.admin?

    if @task.update(task_params)
      render_success(serialize(@task, serializer: TaskSerializer),
                     message: 'Task updated successfully')
    else
      render_validation_error(@task)
    end
  end

  # PATCH /api/v1/tasks/:id/complete  — assigned user only (2.3)
  # User marks their own task as completed → notifies admin (2.4)
  def complete
    # only the assigned user can mark complete — admin cannot
    unless @task.assigned_to == current_user.id
      return render_error('Only the assigned user can mark this task as completed.', :forbidden)
    end

    if @task.completed?
      return render_error('Task is already completed.', :unprocessable_entity)
    end

    @task.update!(status: :completed)

    # 2.4 — notify all admins
    notify_admins_on_action(@task, current_user, 'completed')

    render_success(serialize(@task, serializer: TaskSerializer),
                   message: 'Task marked as completed')
  end

  # PATCH /api/v1/tasks/:id/update_status  — assigned user only (2.3, 2.4)
  # User updates their own task status → notifies admin (2.4)
  def update_status
    # only the assigned user can update status — admin cannot
    unless @task.assigned_to == current_user.id
      return render_error('Only the assigned user can update this task status.', :forbidden)
    end

    new_status = params.dig(:task, :status)

    if new_status.blank?
      return render_error('Status is required.', :unprocessable_entity)
    end

    unless Task.statuses.key?(new_status)
      return render_error("Invalid status. Use: #{Task.statuses.keys.join(', ')}", :unprocessable_entity)
    end

    # prevent going backwards from completed
    if @task.completed?
      return render_error('Completed tasks cannot be changed.', :unprocessable_entity)
    end

    old_status = @task.status
    @task.update!(status: new_status)

    # 2.4 — notify all admins when user takes action
    notify_admins_on_action(@task, current_user, new_status, old_status: old_status)

    render_success(serialize(@task, serializer: TaskSerializer),
                   message: "Task status updated to #{new_status.humanize}")
  end

  # DELETE /api/v1/tasks/:id  — admin only (before_action handles this)
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

  # admin sees all tasks; user sees only their assigned tasks
  def task_scope
    current_user.admin? ? Task.all : Task.where(assigned_to: current_user.id)
  end

  # 2.4 — create notification for every admin when user acts on a task
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
          'actor_id'   => actor.id
        }
      )
    end
  end

  def task_params
    params.require(:task).permit(:title, :description, :assign_date, :due_date, :assigned_to)
  end
end
