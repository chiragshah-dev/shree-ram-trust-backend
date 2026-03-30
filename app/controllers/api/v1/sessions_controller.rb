class Api::V1::SessionsController < Api::V1::BaseController
  protect_from_forgery with: :null_session
  respond_to :json
  skip_before_action :authenticate_user!, only: [:create]

  # POST /api/v1/login
  def create
    user = User.find_by(email: params.dig(:user, :email)&.downcase&.strip)

    if user&.valid_password?(params.dig(:user, :password))
      unless user.active?
        return render_error('Your account is inactive. Contact admin.', :unauthorized)
      end

      if params.dig(:user, :fcm_token).present?
        user.update(fcm_token: params.dig(:user, :fcm_token))
      end

      token = JsonWebToken.encode(user_id: user.id, role: user.role)

      render_success(
        { token: token, user: serialize(user, serializer: UserSerializer) },
        message: 'Login successfully'
      )
    else
      render_error('Invalid email or password', :unauthorized)
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
      user&.update(fcm_token: nil)

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


