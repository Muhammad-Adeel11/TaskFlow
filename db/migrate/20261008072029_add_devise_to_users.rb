# frozen_string_literal: true

class AddDeviseToUsers < ActiveRecord::Migration[8.1]
  def up
    add_col :email,                  :string,   null: false, default: ""
    add_col :encrypted_password,     :string,   null: false, default: ""
    add_col :reset_password_token,   :string
    add_col :reset_password_sent_at, :datetime
    add_col :remember_created_at,    :datetime

    add_unique_index :email
    add_unique_index :reset_password_token
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def add_col(name, type, **options)
    return if column_exists?(:users, name)
    add_column :users, name, type, **options
  end

  def add_unique_index(column)
    return if index_exists?(:users, column)
    add_index :users, column, unique: true
  end
end