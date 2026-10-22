class ConfirmExistingUsers < ActiveRecord::Migration[8.1]
  def up
    now = connection.quote(Time.current.utc.to_fs(:db))

    execute <<~SQL.squish
      UPDATE users
      SET confirmed_at = #{now},
          confirmation_token = NULL,
          confirmation_sent_at = NULL
      WHERE confirmed_at IS NULL
    SQL
  end

  def down
  end
end