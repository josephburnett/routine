class AddBackupFrequencyToUserSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :user_settings, :backup_frequency, :string, default: 'daily'
  end
end
