class Api::V1::ReportsController < Api::V1::BaseController

  # GET /api/v1/reports/daily?date=2025-03-26
  def daily
    date  = params[:date]&.to_date || Date.today
    p report_scope
    tasks = report_scope
              .where(due_date: date.beginning_of_day..date.end_of_day)
              .includes(:creator, :assignee)

    render_success(
      build_report(tasks, "Daily Report — #{date.strftime('%d %b %Y')}"),
      message: 'Daily report fetched'
    )
  end

  # GET /api/v1/reports/my_daily
  def my_daily
    date  = Date.today
    tasks = Task.where(assigned_to: current_user.id)
                .where(due_date: date.beginning_of_day..date.end_of_day)
                .includes(:creator, :assignee)

    render_success(
      build_report(tasks, "My Daily Report — #{date.strftime('%d %b %Y')}"),
      message: 'Your daily report fetched'
    )
  end

  # POST /api/v1/reports/custom
  def custom
    return admin_only! unless current_user.admin?

    tasks = Task.all.includes(:creator, :assignee)
    tasks = tasks.where('due_date >= ?', params[:from].to_date.beginning_of_day) if params[:from].present?
    tasks = tasks.where('due_date <= ?', params[:to].to_date.end_of_day)         if params[:to].present?
    tasks = tasks.where(assigned_to: params[:user_id])                           if params[:user_id].present?
    tasks = tasks.where(status: params[:status])                                 if params[:status].present?

    render_success(
      build_report(tasks, 'Custom Report'),
      message: 'Custom report generated'
    )
  end

  private

  def report_scope
    current_user.admin? ? Task.all : Task.where(assigned_to: current_user.id)
  end

  def build_report(tasks, title)
    {
      title:        title,
      generated_at: Time.zone.now,
      summary: {
        total:       tasks.count,
        completed:   tasks.completed.count,
        pending:     tasks.pending.count,
        in_progress: tasks.in_progress.count,
        overdue:     tasks.overdue.count
      },
      tasks: serialize(tasks, each_serializer: TaskSerializer)
    }
  end
end
