class Api::V1::UsersController < Api::V1::BaseController
  before_action :admin_only!, except: [:show]
  before_action :set_user,    only: [:show, :update, :destroy, :toggle_active]

  # GET /api/v1/users
  def index
    users = User.user
    # users = users.where(role: params[:role])     if params[:role].present?
    users = users.where(active: params[:active]) if params[:active].present?
    if params[:search].present?
      q = "%#{params[:search]}%"
      users = users.where('name ILIKE :q OR email ILIKE :q', q: q)
    end
    users = users.order(created_at: :desc).page(params[:page]).per(params[:per_page] || 10)

    render_list(
      serialize(users, each_serializer: UserSerializer, stats: true), message: 'Users List',
      meta: pagination_meta(users)
    )
  end

  # POST /api/v1/users
  def create
    # user = User.new(user_params)
    # user.password              = params.dig(:user, :password)
    # user.password_confirmation = params.dig(:user, :password_confirmation)

    # if user.save
    #   render_success(
    #     serialize(user, serializer: UserSerializer),
    #     message: 'User created successfully',
    #     status: :created
    #   )
    # else
    #   render_validation_error(user)
    # end
    plain_password = params.dig(:user, :password)

    user = User.new(user_params)
    user.password              = plain_password
    user.password_confirmation = params.dig(:user, :password_confirmation)

    if user.save
      # send welcome email with credentials
      UserMailer.welcome_email(user, plain_password).deliver_later

      render_success(
        serialize(user, serializer: UserSerializer),
        message: 'User created successfully. Login credentials sent to their email.',
        status: :created
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
    render_success(serialize(@user, serializer: UserSerializer, stats: true))
  end

  # PATCH /api/v1/users/:id
  def update
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
    @user.update!(active: false)
    render_success(nil, message: 'User deactivated successfully')
  end

  private

  def set_user
    @user = User.find(params[:id])
  rescue ActiveRecord::RecordNotFound
    render_error('User not found', :not_found)
  end

  def user_params
    params.require(:user).permit(:name, :email, :role, :active, :fcm_token)
  end
end
