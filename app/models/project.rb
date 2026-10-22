class Project < ApplicationRecord
  has_many :tasks, dependent: :destroy
  has_many :memberships, dependent: :destroy
  has_many :members, through: :memberships, source: :user
  
  validates :name, presence: true

  def self.ransackable_attributes(auth_object = nil)
    %w[name description created_at]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[tasks]
  end
end