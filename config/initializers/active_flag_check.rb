# Active Flag Check - Ensures only one deployment is active at a time
#
# This initializer checks for the presence of an ACTIVE_FLAG file that indicates
# this deployment is authorized to run. This prevents accidentally running
# multiple deployments with potentially conflicting data.

# TEMPORARILY DISABLED FOR INITIAL DEPLOYMENT
# TODO: Re-enable after successful deployment
puts "⏭️  Flag check temporarily disabled for initial deployment"

# Rails.application.configure do
#   # Skip flag check in test environment
#   next if Rails.env.test?
#   
#   # Skip flag check during Docker build process
#   # During build, volumes aren't mounted yet so flag won't be accessible
#   if ENV['RAILS_ENV'] != 'production' || 
#      ENV['DOCKER_BUILDKIT'] == '1' || 
#      ENV['BUILDX_BUILDER'] ||
#      ENV.key?('BUILD_CONTEXT') ||
#      !File.directory?(Rails.root.join('storage'))
#     puts "⏭️  Skipping flag check (build context or storage not available)"
#     next
#   end
#   
#   flag_file = Rails.root.join('storage', 'ACTIVE_FLAG')
#   
#   # Add a small retry mechanism in case volume mounting has a slight delay
#   flag_exists = false
#   attempts = 0
#   max_attempts = 3
#   
#   while attempts < max_attempts && !flag_exists
#     flag_exists = File.exist?(flag_file)
#     if !flag_exists && attempts < max_attempts - 1
#       puts "⏳ Flag check attempt #{attempts + 1}/#{max_attempts} - waiting for storage..."
#       sleep(1)
#     end
#     attempts += 1
#   end
#   
#   unless flag_exists
#     # Create a custom exception for missing flag
#     class MissingActiveFlagError < StandardError; end
#     
#     error_message = <<~ERROR
#       
#       ❌ MISSING ACTIVE FLAG
#       
#       This deployment is not authorized to start because it's missing the ACTIVE_FLAG file.
#       
#       The flag system ensures only one deployment (Pi or laptop) runs at a time to prevent
#       data conflicts when traveling between home.local and localhost.
#       
#       To transfer the flag to this deployment, run:
#         ./scripts/transfer_flag.sh #{ENV.fetch('APPLICATION_HOST', 'unknown')}
#       
#       Flag file expected at: #{flag_file}
#       Current host: #{ENV.fetch('APPLICATION_HOST', 'unknown')}
#       Environment: #{Rails.env}
#       Storage directory exists: #{File.directory?(Rails.root.join('storage'))}
#       
#     ERROR
#     
#     # Log the error
#     Rails.logger.error error_message
#     
#     # In development, just warn but allow startup for easier development
#     if Rails.env.development?
#       puts "⚠️  WARNING: #{error_message}"
#       puts "⚠️  Continuing startup in development mode..."
#     else
#       # In production, prevent startup
#       raise MissingActiveFlagError, error_message
#     end
#   else
#     # Flag exists, log the successful validation
#     flag_content = File.read(flag_file).strip rescue "No content"
#     Rails.logger.info "✅ Active flag validated for #{ENV.fetch('APPLICATION_HOST', 'unknown')}: #{flag_content}"
#     puts "✅ Active flag validated: #{flag_content}"
#   end
# end