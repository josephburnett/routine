class AddRememberNamespaceToReports < ActiveRecord::Migration[8.0]
  def change
    add_column :reports, :remember_namespace, :string
  end
end
