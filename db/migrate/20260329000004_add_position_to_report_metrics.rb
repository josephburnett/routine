class AddPositionToReportMetrics < ActiveRecord::Migration[8.0]
  def up
    add_column :report_metrics, :position, :integer, null: false, default: 0
    add_index :report_metrics, [ :report_id, :position ]

    execute <<-SQL
      UPDATE report_metrics SET position = (
        SELECT COUNT(*) FROM report_metrics rm2
        WHERE rm2.report_id = report_metrics.report_id
        AND rm2.id < report_metrics.id
      )
    SQL
  end

  def down
    remove_index :report_metrics, [ :report_id, :position ]
    remove_column :report_metrics, :position
  end
end
