class AddUserIdToSections < ActiveRecord::Migration[8.0]
  def change
    add_reference :sections, :user, null: true, foreign_key: true
  end
end
