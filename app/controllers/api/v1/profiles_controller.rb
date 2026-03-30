class Api::V1::ProfilesController < Api::V1::BaseController

  # GET /api/v1/profile
  def show
    render_success(
      serialize(current_user, serializer: UserSerializer, stats: true),
      message: 'Profile fetched successfully'
    )
  end

  # PATCH /api/v1/profile
  def update
    if current_user.update(profile_params)
      render_success(serialize(current_user, serializer: UserSerializer),
                     message: 'Profile updated successfully')
    else
      render_validation_error(current_user)
    end
  rescue ActionController::ParameterMissing => e
    render_error(e.message, :unprocessable_entity)

  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.join(', '), :unprocessable_entity)

  rescue StandardError => e
    Rails.logger.error("Profile Update Error: #{e.message}")
    render_error('Something went wrong', :internal_server_error)
  end

  # PATCH /api/v1/profile/change_password
  def change_password
    unless current_user.valid_password?(params.dig(:user, :current_password))
      return render_error('Current password is incorrect', :unprocessable_entity)
    end

    new_pw  = params.dig(:user, :password)
    confirm = params.dig(:user, :password_confirmation)

    if new_pw != confirm
      return render_error('Password and confirmation do not match')
    end

    if current_user.update(password: new_pw, password_confirmation: confirm)
      render_success(nil, message: 'Password changed successfully')
    else
      render_validation_error(current_user)
    end
  end

  private

  def profile_params
    params.require(:user).permit(:name, :fcm_token)
  end
end
