class Api::V1::NotificationsController < Api::V1::BaseController

  # GET /api/v1/notifications
  def index
    notifications = current_user.notifications.recent
                                .page(params[:page]).per(params[:per_page] || 10)
    render_list(
      serialize(notifications, each_serializer: NotificationSerializer),
      meta: pagination_meta(notifications).merge(
        unread_count: current_user.notifications.unread.count
      )
    )
  end

  # GET /api/v1/notifications/unread_count
  def unread_count
    render_success({ unread_count: current_user.notifications.unread.count })
  end

  # PATCH /api/v1/notifications/:id/mark_read
  def mark_read
    n = current_user.notifications.find(params[:id])
    n.mark_as_read!
    render_success(serialize(n, serializer: NotificationSerializer),
                   message: 'Marked as read')
  rescue ActiveRecord::RecordNotFound
    render_error('Notification not found', :not_found)
  end

  # PATCH /api/v1/notifications/mark_all_read
  def mark_all_read
    current_user.notifications.unread.update_all(read_at: Time.zone.now)
    render_success(nil, message: 'All notifications marked as read')
  end
end
