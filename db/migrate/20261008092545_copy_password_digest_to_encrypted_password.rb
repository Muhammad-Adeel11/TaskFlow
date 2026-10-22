class CopyPasswordDigestToEncryptedPassword < ActiveRecord::Migration[8.1]
  def up
    return unless column_exists?(:users, :password_digest)

    execute <<~SQL.squish
      UPDATE users
      SET encrypted_password = password_digest
      WHERE password_digest IS NOT NULL
        AND password_digest != ''
    SQL
  end

  def down
  end
end