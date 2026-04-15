class AddReminderFlagsToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :notified_3h, :boolean
    add_column :tasks, :notified_1h, :boolean
  end
end
