class NotificationSerializer < ActiveModel::Serializer
  attributes :id, :notify_type, :params, :created_at

  # use the model's message method
  attribute :message do
    object.message
  end

  # convert read_at datetime to simple boolean
  attribute :read do
    object.read?
  end
end
