class CreateRemembers < ActiveRecord::Migration[8.0]
  def change
    create_table :remembers do |t|
      t.string :description, null: false
      t.text :background
      t.string :state, null: false, default: "floating"
      t.float :decay, null: false, default: 1.0
      t.string :namespace, null: false, default: ""
      t.boolean :deleted, null: false, default: false
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end

    add_index :remembers, :namespace
    add_index :remembers, :state
    add_index :remembers, :deleted
  end
end
