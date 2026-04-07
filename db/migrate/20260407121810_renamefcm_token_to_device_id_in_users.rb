class RenamefcmTokenToDeviceIdInUsers < ActiveRecord::Migration[8.0]
  def change
    rename_column :users, :fcm_token, :device_id
  end
end
