namespace :remembers do
  desc "Lift floating remembers below their user's minimum decay up to 1-1.5x the minimum"
  task lift_to_minimum: :environment do
    lifted = Remember.floating.not_deleted.includes(user: :user_setting).count(&:lift_to_minimum!)
    puts "Lifted #{lifted} remember(s)"
  end
end
