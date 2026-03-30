module ApplicationHelper
  def active_link?(*controllers)
    controllers.include?(controller_path)
  end

  def task_status_badge(status)
    classes = {
      'pending'     => 'badge-pending',
      'in_progress' => 'badge-progress',
      'completed'   => 'badge-completed',
      'overdue'     => 'badge-overdue'
    }
    content_tag(:span, status.humanize, class: "badge-status #{classes[status]}")
  end
end
