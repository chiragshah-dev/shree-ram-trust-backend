class Admin::UsersController < ApplicationController
  def index
    @users = User.all
    @users = Kaminari.paginate_array(@users).page(params[:page])
  end

  def new
  end

  def edit
  end
end
