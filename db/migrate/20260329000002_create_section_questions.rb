class CreateSectionQuestions < ActiveRecord::Migration[8.0]
  def up
    create_table :section_questions do |t|
      t.references :section, null: false, foreign_key: true
      t.references :question, null: false, foreign_key: true
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :section_questions, [ :section_id, :question_id ], unique: true
    add_index :section_questions, [ :section_id, :position ]

    # Migrate data from old HABTM table
    execute <<-SQL
      INSERT INTO section_questions (section_id, question_id, position, created_at, updated_at)
      SELECT section_id, question_id,
             (SELECT COUNT(*) FROM questions_sections qs2
              WHERE qs2.section_id = questions_sections.section_id
              AND qs2.rowid < questions_sections.rowid),
             CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      FROM questions_sections
    SQL

    drop_table :questions_sections
  end

  def down
    create_table :questions_sections, id: false do |t|
      t.integer :question_id, null: false
      t.integer :section_id, null: false
    end

    execute <<-SQL
      INSERT INTO questions_sections (question_id, section_id)
      SELECT question_id, section_id FROM section_questions ORDER BY section_id, position
    SQL

    drop_table :section_questions
  end
end
