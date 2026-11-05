# The soft minimum is now 1.5x the minimum decay (Remember#soft_min_decay).
class RemoveRememberSoftMinDecayFromUserSettings < ActiveRecord::Migration[8.0]
  def change
    remove_column :user_settings, :remember_soft_min_decay, :float, default: 0.05, null: false
  end
end
