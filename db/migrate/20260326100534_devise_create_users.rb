# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      ## Basic Info
      t.string  :name,          null: false, default: ''
      t.string  :phone_number,  null: false
      t.string  :profile_picture

      ## Role — 0=user, 1=admin
      t.integer :role,          null: false, default: 0

      ## Active flag
      t.boolean :active,        null: false, default: true

      ## Devise — Database Authenticatable
      t.string  :encrypted_password, null: false, default: ''

      ## Devise — Rememberable
      t.datetime :remember_created_at

      ## Devise — Trackable
      t.integer  :sign_in_count,      default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip

      ## FCM
      t.string :fcm_token

      ## OTP
      t.string   :otp_code
      t.datetime :otp_expires_at

      ## MPIN
      # t.string  :mpin_digest
      # t.boolean :mpin_set, default: false, null: false

      t.timestamps null: false
    end

    add_index :users, :phone_number, unique: true
    add_index :users, :role
  end

end
