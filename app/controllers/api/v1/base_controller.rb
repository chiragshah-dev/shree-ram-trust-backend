class Api::V1::BaseController < ApplicationController
  protect_from_forgery with: :null_session
  respond_to :json
  before_action :authenticate_user!

  private

  # ── Auth ──────────────────────────────────────────────
  def authenticate_user!
    token = request.headers['Authorization']&.split(' ')&.last
    return render_error('Token missing', :unauthorized) if token.blank?

    begin
      decoded = JsonWebToken.decode(token)

      # ── check denylist ──────────────────────────────────
      jti = decoded['jti']
      if jti.present? && JwtDenylist.revoked?(jti)
        return render_error('Token has been revoked. Please login again.', :unauthorized)
      end

      user_id       = decoded['user_id'] || decoded[:user_id]
      @current_user = User.find(user_id)

      unless @current_user.active?
        return render_error('Account is inactive', :unauthorized)
      end

    rescue JWT::ExpiredSignature
      render_error('Token has expired. Please login again.', :unauthorized)
    rescue JWT::DecodeError
      render_error('Invalid token.', :unauthorized)
    rescue ActiveRecord::RecordNotFound
      render_error('User not found.', :unauthorized)
    end
  end

  def current_user
    @current_user
  end

  def admin_only!
    render_error('Access denied. Admins only.', :forbidden) unless current_user&.admin?
  end

  # ── Response helpers ───────────────────────────────────

  # single object success
  def render_success(data, message: 'Success', status: :ok)
    render json: { success: true, message: message, data: data }, status: status
  end

  # list with pagination
  def render_list(data, meta: {}, message: 'Success')
    render json: { success: true, message: message, data: data, meta: meta }, status: :ok
  end

  # any error
  def render_error(message, status = :unprocessable_entity, errors: nil)
    body = { success: false, message: message }
    body[:errors] = errors if errors.present?
    render json: body, status: status
  end

  # ActiveRecord validation errors
  def render_validation_error(record)
    render_error(record&.errors&.full_messages&.join(', '), :unprocessable_entity,
                 errors: record&.errors&.full_messages)
  end

  # Kaminari pagination block
  def pagination_meta(collection)
    {
      current_page: collection.current_page,
      total_pages:  collection.total_pages,
      total_count:  collection.total_count,
      per_page:     collection.limit_value
    }
  end

  # Serialize with AMS
  def serialize(resource, serializer: nil, each_serializer: nil, **opts)
    if resource.respond_to?(:each)
      ActiveModelSerializers::SerializableResource.new(
        resource,
        each_serializer: each_serializer,
        **opts
      ).as_json
    else
      ActiveModelSerializers::SerializableResource.new(
        resource,
        serializer: serializer,
        **opts
      ).as_json
    end
  end
end
