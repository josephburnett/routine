class DecayRemembersJob < ApplicationJob
  queue_as :default

  def perform
    Rails.logger.info "Starting daily remember decay process..."

    # Find all floating remembers that need decay applied
    floating_remembers = Remember.floating.not_deleted

    Rails.logger.info "Found #{floating_remembers.count} floating remember(s) to decay"

    decayed_count = 0
    floating_remembers.find_each do |remember|
      remember.apply_decay!
      decayed_count += 1
    end

    Rails.logger.info "Decay process completed. Decayed #{decayed_count} remember(s)"
  end
end
