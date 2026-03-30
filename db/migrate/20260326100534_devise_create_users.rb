# frozen_string_literal: true

class DeviseCreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      ## Basic Info
      t.string :name,   null: false, default: ''
      t.string :phone_number
      t.string :profile_picture

      ## Role  — # 0=user, 1=admin
      t.integer :role, null: false, default: 0

      ## Active flag
      t.boolean :active, null: false, default: true

      ## Devise Database Authenticatable
      t.string :email,              null: false, default: ''
      t.string :encrypted_password, null: false, default: ''

      ## Devise Recoverable
      t.string   :reset_password_token
      t.datetime :reset_password_sent_at

      ## Devise Rememberable
      t.datetime :remember_created_at

      ## Devise Trackable (optional — remove if not needed)
      t.integer  :sign_in_count,      default: 0, null: false
      t.datetime :current_sign_in_at
      t.datetime :last_sign_in_at
      t.string   :current_sign_in_ip
      t.string   :last_sign_in_ip
      t.string   :fcm_token

      t.timestamps null: false
    end

    add_index :users, :email,                unique: true
    add_index :users, :reset_password_token, unique: true
    add_index :users, :role
  end
end
