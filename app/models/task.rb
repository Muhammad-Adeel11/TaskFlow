class Task < ApplicationRecord
  
  STATUSES = %w[pending in_progress completed].freeze
  belongs_to :project
  belongs_to :user
  
  validates :title, presence: true
  validates :status, presence: true, inclusion: { in: STATUSES }

  after_save :ensure_assignee_membership, if: -> { saved_change_to_user_id? && user_id.present? }

  def self.ransackable_attributes(auth_object = nil)
    %w[title description status due_date user_id project_id created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[project user]
  end

  scope :due_bucket, ->(value) {
    case value
    when "overdue"   then where("tasks.due_date < ?", Date.current).where.not(status: "completed")
    when "today"     then where(due_date: Date.current)
    when "this_week" then where(due_date: Date.current..Date.current.end_of_week)
    when "no_date"   then where(due_date: nil)
    end
  }

  def self.ransackable_scopes(auth_object = nil)
    %i[due_bucket]
  end

  private

  def ensure_assignee_membership
    Membership.find_or_create_by!(project_id: project_id, user_id: user_id)
  end
end