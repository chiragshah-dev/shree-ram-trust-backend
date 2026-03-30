# class User < ApplicationRecord
#   enum :role, { admin: 0, worker: 1 }

#   # Include default devise modules. Others available are:
#   # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
#   devise :database_authenticatable, :registerable,
#          :recoverable, :rememberable, :validatable

#   scope :active, -> { where(active: true) }


#   def active_for_authentication?
#     super && active
#   end


# end


class User < ApplicationRecord
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  # role: 0=user, 1=admin  (integer in DB, string in code)
  enum :role, { user: 0, admin: 1 }

  has_many :created_tasks,  class_name: 'Task', foreign_key: 'created_by',  dependent: :destroy
  has_many :assigned_tasks, class_name: 'Task', foreign_key: 'assigned_to', dependent: :nullify
  has_many :notifications,  foreign_key: 'user_id', dependent: :destroy

  validates :name,  presence: true
  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :password_confirmation, presence: true, on: :create

  before_create :set_defaults
  scope :active, -> { where(active: true) }

  # called in controllers/views — checks boolean column
  def active?
    active == true
  end

  # Generate a 6-digit OTP and save it with 10 min expiry
  def generate_otp!
    self.otp_code       = rand(100000..999999).to_s
    self.otp_expires_at = 10.minutes.from_now
    save!(validate: false)
    otp_code
  end

  # Check if OTP is valid and not expired
  def valid_otp?(code)
    otp_code == code.to_s && otp_expires_at.present? && otp_expires_at > Time.zone.now
  end

  # Clear OTP after use
  def clear_otp!
    update_columns(otp_code: nil, otp_expires_at: nil)
  end


  private

  def set_defaults
    self.role ||= :user
  end
end
