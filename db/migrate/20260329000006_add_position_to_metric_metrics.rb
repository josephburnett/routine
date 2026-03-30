class AddPositionToMetricMetrics < ActiveRecord::Migration[8.0]
  def up
    add_column :metric_metrics, :position, :integer, null: false, default: 0
    add_index :metric_metrics, [ :parent_metric_id, :position ]

    execute <<-SQL
      UPDATE metric_metrics SET position = (
        SELECT COUNT(*) FROM metric_metrics mm2
        WHERE mm2.parent_metric_id = metric_metrics.parent_metric_id
        AND mm2.id < metric_metrics.id
      )
    SQL
  end

  def down
    remove_index :metric_metrics, [ :parent_metric_id, :position ]
    remove_column :metric_metrics, :position
  end
end
