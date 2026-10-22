class User < ApplicationRecord
  devise :database_authenticatable,
         :registerable,
         :recoverable,
         :rememberable,
         :validatable,
         :confirmable

  after_initialize :set_default_role, if: :new_record?

  has_many :tasks, dependent: :nullify
  has_many :memberships, dependent: :destroy
  has_many :member_projects, through: :memberships, source: :project
  
  has_one_attached :avatar
  validate :avatar_must_be_a_small_image

  validates :name, presence: true

  def self.ransackable_attributes(auth_object = nil)
    %w[name email role]
  end

  def self.ransackable_associations(auth_object = nil)
    %w[tasks]
  end

  scope :confirmation_state, ->(value) {
    case value
    when "confirmed"   then where.not(confirmed_at: nil)
    when "unconfirmed" then where(confirmed_at: nil)
    end
  }

  def self.ransackable_scopes(auth_object = nil)
    %i[confirmation_state]
  end

  def user?
    role == "user"
  end

  def manager?
    role == "manager"
  end

  def admin?
    role == "admin"
  end

  private

  def set_default_role
    self.role ||= "user"
  end

  def avatar_must_be_a_small_image
    return unless avatar.attached?

    unless avatar.blob.content_type.in?(%w[image/png image/jpeg image/webp image/gif])
      errors.add(:avatar, "must be a PNG, JPG, WEBP or GIF image")
    end

    errors.add(:avatar, "must be smaller than 2 MB") if avatar.blob.byte_size > 2.megabytes
  end
end