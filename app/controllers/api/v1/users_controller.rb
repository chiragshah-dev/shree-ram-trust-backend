class Api::V1::UsersController < Api::V1::BaseController
  before_action :admin_only!, except: [:show]
  before_action :set_user,    only: [:show, :update, :destroy, :toggle_active, :reset_password]

  # GET /api/v1/users
  def index
    users = User.where(role: :user)
    users = users.where(active: params[:active]) if params[:active].present?
    if params[:search].present?
      q = "%#{params[:search]}%"
      users = users.where('name ILIKE :q OR phone_number ILIKE :q', q: q)
    end
    users = users.order(created_at: :desc).page(params[:page]).per(params[:per_page] || 10)

    # preload task counts to avoid N+1
    task_counts = Task.where(assigned_to: users.map(&:id))
                      .group(:assigned_to, :status)
                      .count

    render_list(
      serialize(users, each_serializer: UserSerializer, task_counts: task_counts),
      message: 'Users List',
      meta: pagination_meta(users)
    )
  end

  # POST /api/v1/users
  def create
    plain_password        = params.dig(:user, :password)
    password_confirmation = params.dig(:user, :password_confirmation)

    if plain_password != password_confirmation
      return render_error('Password and password confirmation do not match', :unprocessable_entity)
    end

    user = User.new(user_params)
    user.password              = plain_password
    user.password_confirmation = password_confirmation
    user.temp_password         = plain_password

    if user.save
      render_success(
        serialize(user, serializer: UserSerializer),
        message: 'User created successfully. Share credentials with the user.',
        status:  :created
      )
    else
      render_validation_error(user)
    end
  rescue ActionController::ParameterMissing => e
    render_error(e.message, :unprocessable_entity)
  rescue ActiveRecord::RecordInvalid => e
    render_error(e.record.errors.full_messages.join(', '), :unprocessable_entity)
  rescue StandardError => e
    Rails.logger.error("User Create Error: #{e.message}")
    render_error('Something went wrong', :internal_server_error)
  end

  # GET /api/v1/users/:id
  def show
    unless current_user.admin? || @user.id == current_user.id
      return render_error('Access denied', :forbidden)
    end
    render_success(serialize(@user, serializer: UserSerializer))
  end

  # PATCH /api/v1/users/:id
  def update
    if params.dig(:user, :password).present?
      plain_password        = params.dig(:user, :password)
      password_confirmation = params.dig(:user, :password_confirmation)

      if plain_password != password_confirmation
        return render_error('Password and password confirmation do not match', :unprocessable_entity)
      end

      @user.password              = plain_password
      @user.password_confirmation = password_confirmation
    end

    if @user.update(user_params)
      render_success(serialize(@user, serializer: UserSerializer),
                     message: 'User updated successfully')
    else
      render_validation_error(@user)
    end
  end

  # PATCH /api/v1/users/:id/toggle_active
  def toggle_active
    @user.update!(active: !@user.active?)
    word = @user.active? ? 'activated' : 'deactivated'
    render_success(serialize(@user, serializer: UserSerializer),
                   message: "User #{word} successfully")
  end

  # DELETE /api/v1/users/:id
  def destroy
    @user.destroy!
    render_success(nil, message: 'User deleted successfully')
  end

   # PATCH /api/v1/users/:id/reset_password
  def reset_password
    if params.dig(:user, :password).present?
      plain_password        = params.dig(:user, :password)
      password_confirmation = params.dig(:user, :password_confirmation)

      if plain_password != password_confirmation
        return render_error('Password and password confirmation do not match', :unprocessable_entity)
      end

      @user.password              = plain_password
      @user.password_confirmation = password_confirmation
      @user.temp_password         = plain_password  # refresh temp
    end
    if @user.save
      render_success(serialize(@user, serializer: UserSerializer),
        message: 'Password reset successfully. Share new credentials with the user.'
      )
    else
      render_validation_error(@user)
    end
  end
  private

  def set_user
    @user = User.user.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('User not found', :not_found)
  end

  def user_params
    params.require(:user).permit(:name, :phone_number, :role, :active, :fcm_token)
  end

end
