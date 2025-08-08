class DropDashboardTables < ActiveRecord::Migration[8.0]
  def change
    # Drop join tables first (due to foreign keys)
    drop_table :dashboard_alerts, if_exists: true
    drop_table :dashboard_dashboards, if_exists: true
    drop_table :dashboard_forms, if_exists: true
    drop_table :dashboard_metrics, if_exists: true
    drop_table :dashboard_questions, if_exists: true

    # Drop main dashboards table last
    drop_table :dashboards, if_exists: true
  end
end
