class AddDecayJitterSettingsToUserSettings < ActiveRecord::Migration[8.0]
  def change
    add_column :user_settings, :remember_soft_min_decay, :float, default: 0.05, null: false
    add_column :user_settings, :remember_decay_jitter, :float, default: 0.2, null: false
  end
end
