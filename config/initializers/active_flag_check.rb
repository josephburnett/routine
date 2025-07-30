# Active Flag Check - Ensures only one deployment is active at a time
#
# This initializer checks for the presence of an ACTIVE_FLAG file that indicates
# this deployment is authorized to run. This prevents accidentally running
# multiple deployments with potentially conflicting data.

Rails.application.configure do
  # Skip flag check in test environment
  next if Rails.env.test?
  
  flag_file = Rails.root.join('storage', 'ACTIVE_FLAG')
  
  unless File.exist?(flag_file)
    # Create a custom exception for missing flag
    class MissingActiveFlagError < StandardError; end
    
    error_message = <<~ERROR
      
      ❌ MISSING ACTIVE FLAG
      
      This deployment is not authorized to start because it's missing the ACTIVE_FLAG file.
      
      The flag system ensures only one deployment (Pi or laptop) runs at a time to prevent
      data conflicts when traveling between home.local and localhost.
      
      To transfer the flag to this deployment, run:
        ./scripts/transfer_flag.sh #{ENV.fetch('APPLICATION_HOST', 'unknown')}
      
      Flag file expected at: #{flag_file}
      Current host: #{ENV.fetch('APPLICATION_HOST', 'unknown')}
      Environment: #{Rails.env}
      
    ERROR
    
    # Log the error
    Rails.logger.error error_message
    
    # In development, just warn but allow startup for easier development
    if Rails.env.development?
      puts "⚠️  WARNING: #{error_message}"
      puts "⚠️  Continuing startup in development mode..."
    else
      # In production, prevent startup
      raise MissingActiveFlagError, error_message
    end
  else
    # Flag exists, log the successful validation
    flag_content = File.read(flag_file).strip rescue "No content"
    Rails.logger.info "✅ Active flag validated for #{ENV.fetch('APPLICATION_HOST', 'unknown')}: #{flag_content}"
    puts "✅ Active flag validated: #{flag_content}"
  end
end