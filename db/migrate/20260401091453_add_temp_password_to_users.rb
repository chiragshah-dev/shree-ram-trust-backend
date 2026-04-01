class AddTempPasswordToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :temp_password, :string
  end
end
