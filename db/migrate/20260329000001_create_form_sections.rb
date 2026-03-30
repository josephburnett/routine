class CreateFormSections < ActiveRecord::Migration[8.0]
  def up
    create_table :form_sections do |t|
      t.references :form, null: false, foreign_key: true
      t.references :section, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :form_sections, [ :form_id, :section_id ], unique: true
    add_index :form_sections, [ :form_id, :position ]

    # Migrate data from old HABTM table
    execute <<-SQL
      INSERT INTO form_sections (form_id, section_id, position, created_at, updated_at)
      SELECT form_id, section_id,
             (SELECT COUNT(*) FROM forms_sections fs2
              WHERE fs2.form_id = forms_sections.form_id
              AND fs2.rowid < forms_sections.rowid),
             CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM forms_sections
    SQL

    drop_table :forms_sections
  end

  def down
    create_table :forms_sections, id: false do |t|
      t.integer :form_id, null: false
      t.integer :section_id, null: false
    end

    execute <<-SQL
      INSERT INTO forms_sections (form_id, section_id)
      SELECT form_id, section_id FROM form_sections ORDER BY form_id, position
    SQL

    drop_table :form_sections
  end
end
