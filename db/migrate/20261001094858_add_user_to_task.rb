class AddUserToTask < ActiveRecord::Migration[8.1]
  def change
    add_reference :tasks, :user, foreign_key: true
  end
end
