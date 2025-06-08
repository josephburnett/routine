class AddDeletedToQuestions < ActiveRecord::Migration[8.0]
  def change
    add_column :questions, :deleted, :boolean, default: false, null: false
  end
end
