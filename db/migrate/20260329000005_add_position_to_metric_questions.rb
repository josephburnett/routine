class AddPositionToMetricQuestions < ActiveRecord::Migration[8.0]
  def up
    add_column :metric_questions, :position, :integer, null: false, default: 0
    add_index :metric_questions, [ :metric_id, :position ]

    execute <<-SQL
      UPDATE metric_questions SET position = (
        SELECT COUNT(*) FROM metric_questions mq2
        WHERE mq2.metric_id = metric_questions.metric_id
        AND mq2.id < metric_questions.id
      )
    SQL
  end

  def down
    remove_index :metric_questions, [ :metric_id, :position ]
    remove_column :metric_questions, :position
  end
end
