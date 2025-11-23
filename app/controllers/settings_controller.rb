class SettingsController < ApplicationController
  before_action :require_login

  def show
    @user_setting = current_user.user_setting || current_user.build_user_setting
    @return_namespace = params[:return_namespace]
  end

  def update
    @user_setting = current_user.user_setting || current_user.build_user_setting
    @return_namespace = params[:return_namespace]

    # Generate encryption key if backup is being enabled and no key exists
    if user_setting_params[:backup_enabled] == "1" && @user_setting.encryption_key.blank?
      @user_setting.encryption_key = SecureRandom.base64(32)
    end

    if @user_setting.update(user_setting_params)
      # Return to the namespace user came from
      if @return_namespace.present?
        redirect_to namespace_path(@return_namespace), notice: "Settings updated successfully"
      else
        redirect_to namespaces_path, notice: "Settings updated successfully"
      end
    else
      render :show, status: :unprocessable_entity
    end
  end

  def send_backup_now
    begin
      # Check if backup is enabled
      user_setting = current_user.user_setting
      unless user_setting&.backup_enabled?
        redirect_to settings_path, alert: "Backup is not enabled for your account"
        return
      end

      # Send the backup
      BackupMailer.daily_backup(current_user).deliver_now

      redirect_to settings_path, notice: "Backup sent successfully! Check your email."
    rescue => e
      Rails.logger.error "Failed to send backup for user #{current_user.id}: #{e.message}"
      redirect_to settings_path, alert: "Failed to send backup: #{e.message}"
    end
  end

  private

  def user_setting_params
    params.require(:user_setting).permit(:backup_enabled, :backup_method, :backup_email, :backup_frequency,
                                         :remember_daily_decay, :remember_min_decay)
  end
end
