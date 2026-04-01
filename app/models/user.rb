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
  devise :database_authenticatable, :rememberable


  # role: 0=user, 1=admin  (integer in DB, string in code)
  enum :role, { user: 0, admin: 1 }

  has_many :created_tasks,  class_name: 'Task', foreign_key: 'created_by',  dependent: :destroy
  has_many :assigned_tasks, class_name: 'Task', foreign_key: 'assigned_to', dependent: :nullify
  has_many :notifications,  foreign_key: 'user_id', dependent: :destroy

  validates :name, presence: true
  validates :phone_number,
            presence: true,
            uniqueness: true,
            format: { with: /\A\+91[6-9]\d{9}\z/, message: 'must be a valid Indian mobile number with +91' }
  validates :password, presence: true, length: { minimum: 6 }, on: :create
  validates :password_confirmation, presence: true, on: :create

  before_create :set_defaults
  scope :active, -> { where(active: true) }

  # called in controllers/views — checks boolean column
  def active?
    active == true
  end

  def mpin_set?
    mpin_set == true && mpin_digest.present?
  end

  def set_mpin!(mpin)
    self.mpin_digest = BCrypt::Password.create(mpin)
    self.mpin_set    = true
    save!(validate: false)
  end

  def valid_mpin?(mpin)
    return false unless mpin_digest.present?
    BCrypt::Password.new(mpin_digest) == mpin
  end

  def clear_temp_password!
    update_column(:temp_password, nil)
  end

  private

  def set_defaults
    self.mpin_set = false if mpin_set.nil?
    self.role   ||= :user
  end
end
