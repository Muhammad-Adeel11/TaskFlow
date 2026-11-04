class GoogleConnection < ApplicationRecord
  belongs_to :user

  encrypts :access_token, :refresh_token

  validates :refresh_token, presence: true
end