class TaskSerializer < ActiveModel::Serializer
  attributes :id,
             :title,
             :description,
             :notes,
             :priority,
             :status,
             :assign_date,
             :due_date,
             :created_by,
             :assigned_to,
             :created_at,
             :updated_at,
             :assignee,
             :creator,
             :overdue,
             :voice_note_url

  def assignee
    return nil unless object.assignee
    {
      id: object.assignee.id,
      name: object.assignee.name,
      phone_number: object.assignee.phone_number,
    }
  end

  def creator
    return nil unless object.creator
    {
      id: object.creator.id,
      name: object.creator.name,
    }
  end

  def overdue
    return false if object.completed?
    object.due_date < Time.current
  end

  def voice_note_url
    object.voice_note.attached? ? Rails.application.routes.url_helpers.rails_blob_url(object.voice_note, only_path: false) : nil
  end
end
