class Api::V1::ReportsController < Api::V1::BaseController
  require 'csv'

  # GET /api/v1/reports/daily?date=2025-03-26
  def daily
    date  = params[:date]&.to_date || Date.today
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
    csv_url = generate_csv_url(tasks, title)
    {
      title:        title,
      generated_at: Time.zone.now,
      csv_file:     csv_url,           # ← URL returned here
      summary: {
        total:       tasks.count,
        completed:   tasks.completed.count,
        pending:     tasks.pending.count,
        in_progress: tasks.in_progress.count,
        overdue:     tasks.overdue.count
      }
      # tasks: serialize(tasks, each_serializer: TaskSerializer)
    }
  end

  def generate_csv_url(tasks, title)
    # build CSV string
    csv_data = CSV.generate(headers: true) do |csv|
      csv << ['ID', 'Title', 'Description', 'Status', 'Priority',
              'Assigned To', 'Created By', 'Assign Date', 'Due Date', 'Notes', 'Created At']
      tasks.each do |task|
        csv << [
          task.id,
          task.title,
          task.description,
          task.status&.humanize,
          task.priority&.humanize,
          task.assignee&.name,
          task.creator&.name,
          task.assign_date&.strftime('%d %b %Y, %I:%M %p'),
          task.due_date&.strftime('%d %b %Y, %I:%M %p'),
          task.notes,
          task.created_at&.strftime('%d %b %Y, %I:%M %p')
        ]
      end
    end

    # upload to Active Storage
    filename = "#{title.parameterize}_#{Time.zone.now.strftime('%Y%m%d%H%M%S')}.csv"
    blob = ActiveStorage::Blob.create_and_upload!(
      io:           StringIO.new(csv_data),
      filename:     filename,
      content_type: 'text/csv'
    )

    # return a public URL (expires in 1 hour)
    Rails.application.routes.url_helpers.rails_blob_url(blob, expires_in: 1.hour)
  end
end
