class CreateMemberships < ActiveRecord::Migration[8.1]
  def change
    create_table :memberships do |t|
      t.references :user, null: false, foreign_key: true
      t.references :project, null: false, foreign_key: true

      t.timestamps
    end

    add_index :memberships, [:user_id, :project_id], unique: true

    # Keep existing access: everyone who already has a task in a project becomes a member
    reversible do |dir|
      dir.up do
        execute <<~SQL
          INSERT INTO memberships (user_id, project_id, created_at, updated_at)
          SELECT DISTINCT user_id, project_id, datetime('now'), datetime('now')
          FROM tasks
          WHERE user_id IS NOT NULL
        SQL
      end
    end
  end
end