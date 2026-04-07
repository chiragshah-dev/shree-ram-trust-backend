class Notification < ApplicationRecord
  belongs_to :user

  validates :notify_type, presence: true
  validates :user_id,     presence: true

  scope :unread,  -> { where(read_at: nil) }
  scope :recent,  -> { order(created_at: :desc) }

  def read?
    read_at.present?
  end

  def mark_as_read!
    update!(read_at: Time.zone.now)
  end

  # Human-readable message built from stored params
  def message
    params['message'].to_s
  end
end
