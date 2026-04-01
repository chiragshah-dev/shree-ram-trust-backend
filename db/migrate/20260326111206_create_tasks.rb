class CreateTasks < ActiveRecord::Migration[8.0]
  def change
    create_table :tasks do |t|
      t.string   :title,       null: false
      t.text     :description
      t.datetime :assign_date, null: false
      t.datetime :due_date,    null: false
      t.integer  :status,      null: false, default: 0  # 0=pending,1=in_progress,2=completed,3=overdue
      t.integer  :created_by,  null: false
      t.integer  :assigned_to, null: false
      t.integer  :priority,    null: false, default: 0
      t.text     :notes
      t.timestamps
    end

    # indexes make queries faster
    add_index :tasks, :created_by
    add_index :tasks, :assigned_to
    add_index :tasks, :status
    add_index :tasks, :due_date
    add_index :tasks, :priority
  end
end
