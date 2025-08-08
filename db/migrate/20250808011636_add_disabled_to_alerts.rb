class AddDisabledToAlerts < ActiveRecord::Migration[8.0]
  def change
    add_column :alerts, :disabled, :boolean, default: false, null: false
  end
end
