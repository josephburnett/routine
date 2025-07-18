class AddDisabledToMetrics < ActiveRecord::Migration[8.0]
  def change
    add_column :metrics, :disabled, :boolean, default: false, null: false
  end
end
