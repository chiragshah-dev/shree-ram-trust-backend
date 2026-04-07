class Api::V1::SessionsController < Api::V1::BaseController
  protect_from_forgery with: :null_session
  respond_to :json
  skip_before_action :authenticate_user!, only: [:create]

  # POST /api/v1/login
  # def create
  #   user = User.find_by(email: params.dig(:user, :email)&.downcase&.strip)

  #   if user&.valid_password?(params.dig(:user, :password))
  #     unless user.active?
  #       return render_error('Your account is inactive. Contact admin.', :unauthorized)
  #     end

  #     if params.dig(:user, :device_id).present?
  #       user.update(device_id: params.dig(:user, :device_id))
  #     end

  #     token = JsonWebToken.encode(user_id: user.id, role: user.role)

  #     render_success(
  #       { token: token, user: serialize(user, serializer: UserSerializer) },
  #       message: 'Login successfully'
  #     )
  #   else
  #     render_error('Invalid email or password', :unauthorized)
  #   end
  # end

  def create
    # Normalize phone: accept "9999999999" or "+919999999999"
    raw_phone = params.dig(:user, :phone_number).to_s.strip
    phone = raw_phone.start_with?('+') ? raw_phone : "+91#{raw_phone}"

    user = User.find_by(phone_number: phone)

    if user&.valid_password?(params.dig(:user, :password))
      unless user.active?
        return render_error('Your account is inactive. Contact admin.', :unauthorized)
      end

      if params.dig(:user, :device_id).present?
        user.update(device_id: params.dig(:user, :device_id))
      end

      token = JsonWebToken.encode(user_id: user.id, role: user.role)

      render_success(
        {
          token: token,
          user: serialize(user, serializer: UserSerializer)
        },
        message: 'Login successfully'
      )
    else
      render_error('Invalid phone number or password', :unauthorized)
    end
  end

  def destroy
    jwt_token = request.headers['Authorization']&.split(' ')&.last

    unless jwt_token.present?
      return render_error('Token missing', :unauthorized)
    end

    begin
      jwt_payload = JsonWebToken.decode(jwt_token)

      jti = jwt_payload['jti']
      exp = jwt_payload['exp']

      # ── add token to denylist ──────────────────────────
      if jti.present?
        JwtDenylist.revoke!(jti, exp)
      end

      user = User.find_by(id: jwt_payload['user_id'])
      user&.update(device_id: nil)

      render_success(nil, message: 'Logged out successfully')

    rescue JWT::ExpiredSignature
      # expired token — still treat as logged out
      render_success(nil, message: 'Logged out successfully')
    rescue JWT::DecodeError
      render_error('Invalid token', :unauthorized)
    rescue StandardError => e
      render_error('Logout failed', :internal_server_error, errors: [e.message])
    end
  end
end


