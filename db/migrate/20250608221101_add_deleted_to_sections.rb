class AddDeletedToSections < ActiveRecord::Migration[8.0]
  def change
    add_column :sections, :deleted, :boolean, default: false, null: false
  end
end
