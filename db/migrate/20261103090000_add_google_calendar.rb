class AddGoogleCalendar < ActiveRecord::Migration[8.1]
  def change
    # one Google connection per user (tokens are stored encrypted)
    create_table :google_connections do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.text :access_token
      t.text :refresh_token, null: false
      t.datetime :expires_at
      t.string :calendar_id
      t.timestamps
    end

    # remembers which Google event belongs to which task
    add_column :tasks, :google_event_id, :string
    add_column :tasks, :google_event_user_id, :integer
  end
end