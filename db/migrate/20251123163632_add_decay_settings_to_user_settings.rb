class AddDecaySettingsToUserSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :user_settings, :remember_daily_decay, :float, null: false, default: 0.05
    add_column :user_settings, :remember_min_decay, :float, null: false, default: 0.01
  end
end
