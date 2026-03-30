class Admin::DashboardController < ApplicationController
  before_action :authenticate_user!
  before_action :require_admin

  def index
    # @users_count = User.count
    # @tasks_count = Task.count

    base = current_user.admin? ? Task.all : Task.where(assigned_to: current_user.id)
    @today_tasks    = base.today.includes(:creator, :assignee)
    @upcoming_tasks = base.upcoming.limit(10).includes(:creator, :assignee)
    @overdue_tasks  = base.overdue.includes(:creator, :assignee)
    @total_count     = base.count
    @completed_count = base.completed.count
    @pending_count   = base.pending.count
    @overdue_count   = base.overdue.count

  end

  private

  def require_admin
    unless current_user&.admin?
      redirect_to new_user_session_path, alert: "Access denied"
    end
  end
end
