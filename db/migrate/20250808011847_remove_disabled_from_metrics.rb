class RemoveDisabledFromMetrics < ActiveRecord::Migration[8.0]
  def change
    remove_column :metrics, :disabled, :boolean, default: false, null: false
  end
end
