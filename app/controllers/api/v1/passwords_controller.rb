# app/controllers/api/v1/passwords_controller.rb
class Api::V1::PasswordsController < Api::V1::BaseController
  skip_before_action :authenticate_user!, only: [:forgot, :verify_otp, :reset]

  # POST /api/v1/passwords/forgot
  def forgot
    email = params.dig(:user, :email)&.downcase&.strip

    if email.blank?
      return render_error('Email is required', :unprocessable_entity)
    end

    user = User.find_by(email: email)

    if user.nil?
      return render_error('No account found with this email address', :not_found)
    end

    unless user.active?
      return render_error('Your account is inactive. Contact admin.', :unauthorized)
    end

    user.generate_otp!
    UserMailer.forgot_password_email(user).deliver_later

    render_success(nil, message: 'OTP has been sent to your email.')
  end

  # POST /api/v1/passwords/verify_otp
  def verify_otp
    email = params.dig(:user, :email)&.downcase&.strip
    otp   = params.dig(:user, :otp)

    if email.blank?
      return render_error('Email is required', :unprocessable_entity)
    end

    if otp.blank?
      return render_error('OTP is required', :unprocessable_entity)
    end

    user = User.find_by(email: email)

    if user.nil?
      return render_error('No account found with this email address', :not_found)
    end

    unless user.active?
      return render_error('Your account is inactive. Contact admin.', :unauthorized)
    end

    unless user.valid_otp?(otp)
      return render_error('OTP is invalid or has expired', :unprocessable_entity)
    end

    reset_token = JsonWebToken.encode(
      { user_id: user.id, purpose: 'password_reset' },
      15.minutes.from_now
    )

    render_success(
      { reset_token: reset_token },
      message: 'OTP verified. Use the reset_token to set new password.'
    )
  end

  # POST /api/v1/passwords/reset
  def reset
    reset_token    = params.dig(:user, :reset_token)
    new_password   = params.dig(:user, :password)
    confirm        = params.dig(:user, :password_confirmation)

    # validate all fields upfront
    if reset_token.blank?
      return render_error('Reset token is required', :unprocessable_entity)
    end

    if new_password.blank?
      return render_error('New password is required', :unprocessable_entity)
    end

    if confirm.blank?
      return render_error('Password confirmation is required', :unprocessable_entity)
    end

    if new_password != confirm
      return render_error('Password and confirmation do not match', :unprocessable_entity)
    end

    if new_password.length < 8
      return render_error('Password must be at least 8 characters', :unprocessable_entity)
    end

    # decode token
    begin
      payload = JsonWebToken.decode(reset_token)
    rescue JWT::ExpiredSignature
      return render_error('Reset token has expired. Please request a new OTP.', :unauthorized)
    rescue JWT::DecodeError
      return render_error('Invalid reset token', :unprocessable_entity)
    end

    # validate token purpose
    unless payload['purpose'] == 'password_reset'
      return render_error('Invalid reset token', :unprocessable_entity)
    end

    # find user separately so we can give a clear error
    user = User.find_by(id: payload['user_id'])

    if user.nil?
      return render_error('User not found. Please request a new OTP.', :not_found)
    end

    unless user.active?
      return render_error('Your account is inactive. Contact admin.', :unauthorized)
    end

    # update password
    unless user.update(password: new_password, password_confirmation: confirm)
      return render_validation_error(user)
    end

    user.clear_otp!

    UserMailer.password_reset_success_email(user).deliver_later

    render_success(nil, message: 'Password reset successfully. Please login.')
  end
end
