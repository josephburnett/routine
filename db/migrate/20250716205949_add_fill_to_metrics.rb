class AddFillToMetrics < ActiveRecord::Migration[8.0]
  def change
    add_column :metrics, :fill, :string, default: 'none'
  end
end
