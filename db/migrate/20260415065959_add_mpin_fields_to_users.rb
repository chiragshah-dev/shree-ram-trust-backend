class AddMpinFieldsToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :mpin_digest, :string
    add_column :users, :mpin_set, :boolean, default: false, null: false
  end
end
