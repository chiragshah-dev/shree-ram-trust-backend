class UserMailer < ApplicationMailer

  # Called when admin creates a new user
  def welcome_email(user, plain_password)
    @user           = user
    @plain_password = plain_password

    mail(
      to:      @user.email,
      subject: 'Welcome! Your account has been created'
    )
  end

  # Called when user requests forgot password OTP
  def forgot_password_email(user)
    @user = user
  @otp  = user.otp_code

    mail(
      to:      @user.email,
      subject: 'Password Reset OTP'
    )
  end

  # Called when password is successfully reset
  def password_reset_success_email(user)
    @user = user

    mail(
      to:      @user.email,
      subject: 'Your password has been reset'
    )
  end
end
