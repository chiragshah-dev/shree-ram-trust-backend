# app/controllers/api/v1/mpins_controller.rb
class Api::V1::MpinsController < Api::V1::BaseController

  # POST /api/v1/mpin/set
  def set_mpin
    mpin = params[:mpin].to_s.strip

    return render_error('MPIN must be 4–6 digits', :unprocessable_entity) unless mpin.match?(/\A\d{4,6}\z/)

    if current_user.mpin_set?
      return render_error('MPIN already set. Use change MPIN flow.', :unprocessable_entity)
    end

    current_user.set_mpin!(mpin)
    render_success(
      { user: serialize(current_user, serializer: UserSerializer) },
      message: 'MPIN set successfully'
    )
  end

  # POST /api/v1/mpin/verify
  def verify_mpin
    mpin = params[:mpin].to_s.strip

    unless current_user.mpin_set?
      return render_error('MPIN not set. Please login with password first.', :unprocessable_entity)
    end

    unless current_user.valid_mpin?(mpin)
      return render_error('Invalid MPIN', :unauthorized)
    end

    render_success(
      { user: serialize(current_user, serializer: UserSerializer) },
      message: 'MPIN verified successfully'
    )
  end

  # PUT /api/v1/mpin/change
  def change_mpin
    old_mpin = params[:old_mpin].to_s.strip
    new_mpin = params[:new_mpin].to_s.strip

    unless current_user.mpin_set?
      return render_error('MPIN not set. Use set MPIN first.', :unprocessable_entity)
    end

    unless current_user.valid_mpin?(old_mpin)
      return render_error('Old MPIN is incorrect', :unauthorized)
    end

    return render_error('New MPIN must be 4–6 digits', :unprocessable_entity) unless new_mpin.match?(/\A\d{4,6}\z/)

    if old_mpin == new_mpin
      return render_error('New MPIN must be different from old MPIN', :unprocessable_entity)
    end

    current_user.set_mpin!(new_mpin)
    # render_success(nil, message: 'MPIN changed successfully')
    render_success(
      { user: serialize(current_user, serializer: UserSerializer) },
      message: 'MPIN changed successfully'
    )
  end

  # POST /api/v1/mpin/mpin_reset
  def mpin_reset
    # Check if the current user is an admin
    unless current_user.admin?
      return render_error('Unauthorized', :unauthorized)
    end

    # Find the user by ID passed in the params
    user = User.find_by(id: params[:user_id])
    return render_error('User not found', :not_found) unless user

    # Reset the MPIN for the user
    user.update(mpin_set: false, mpin_digest: nil)

    render_success(
      { user: serialize(user, serializer: UserSerializer) },
      message: 'MPIN reset successfully. User can now set a new MPIN.'
    )
  end
end
