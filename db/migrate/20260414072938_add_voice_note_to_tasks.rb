class AddVoiceNoteToTasks < ActiveRecord::Migration[8.0]
  def change
    add_column :tasks, :voice_note, :string
  end
end
