class SendDailyBackupsJob < ApplicationJob
  queue_as :default

  def perform(frequency = "daily")
    Rails.logger.info "Starting #{frequency} backup process..."

    # Find all users with backup enabled for the specified frequency
    users_with_backups = User.joins(:user_setting)
                             .where(user_settings: {
                               backup_enabled: true,
                               backup_frequency: frequency
                             })
                             .where.not(user_settings: { backup_email: [ nil, "" ] })
                             .where.not(user_settings: { encryption_key: [ nil, "" ] })

    Rails.logger.info "Found #{users_with_backups.count} user(s) with #{frequency} backups enabled"

    users_with_backups.find_each do |user|
      begin
        Rails.logger.info "Sending #{frequency} backup for user: #{user.name} (#{user.email})"
        BackupMailer.daily_backup(user).deliver_now
        Rails.logger.info "Backup sent successfully to #{user.user_setting.backup_email}"
      rescue => e
        Rails.logger.error "Failed to send #{frequency} backup for #{user.name}: #{e.message}"
        raise e
      end
    end

    Rails.logger.info "#{frequency.capitalize} backup process completed"
  end
end
