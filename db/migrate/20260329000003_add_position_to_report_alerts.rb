class AddPositionToReportAlerts < ActiveRecord::Migration[8.0]
  def up
    add_column :report_alerts, :position, :integer, null: false, default: 0
    add_index :report_alerts, [ :report_id, :position ]

    # Assign sequential positions per report
    execute <<-SQL
      UPDATE report_alerts SET position = (
        SELECT COUNT(*) FROM report_alerts ra2
        WHERE ra2.report_id = report_alerts.report_id
        AND ra2.id < report_alerts.id
      )
    SQL
  end

  def down
    remove_index :report_alerts, [ :report_id, :position ]
    remove_column :report_alerts, :position
  end
end
