class CreateNotifications < ActiveRecord::Migration[8.0]
  def change
    create_table :notifications do |t|
      t.integer  :user_id,     null: false
      t.string   :notify_type, null: false
      t.jsonb    :params,      null: false, default: {}
      t.datetime :read_at                                # nil = unread

      t.timestamps
    end

    add_index :notifications, :user_id
    add_index :notifications, [:user_id, :read_at]      # speeds up unread queries
  end

end
