class TaskSerializer < ActiveModel::Serializer
  attributes :id, :title, :description, :status,
             :assign_date, :due_date, :created_at, :updated_at

  # embed assignee as object, not just ID
  attribute :assigned_to do
    {
      id:    object.assignee&.id,
      name:  object.assignee&.name,
      email: object.assignee&.email
    }
  end

  # embed creator as object
  attribute :created_by do
    {
      id:   object.creator&.id,
      name: object.creator&.name
    }
  end

  # computed field — true if past due and not completed
  attribute :is_overdue do
    object.due_date.present? && object.due_date < Time.zone.now && !object.completed?
  end
end
