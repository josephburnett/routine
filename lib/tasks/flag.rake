namespace :flag do
  desc "Create the ACTIVE_FLAG file for this deployment"
  task :create, [:source_host] => :environment do |t, args|
    source_host = args[:source_host] || "manual"
    current_host = ENV.fetch('APPLICATION_HOST', 'unknown')
    timestamp = Time.current.utc.iso8601
    
    flag_file = Rails.root.join('storage', 'ACTIVE_FLAG')
    
    flag_content = <<~FLAG
      ACTIVE_FLAG
      Created: #{timestamp}
      Host: #{current_host}
      Source: #{source_host}
      Transfer ID: #{SecureRandom.hex(8)}
    FLAG
    
    File.write(flag_file, flag_content)
    
    puts "✅ Active flag created for #{current_host}"
    puts "📁 Location: #{flag_file}"
    puts "📝 Content:"
    puts flag_content.indent(2)
  end
  
  desc "Remove the ACTIVE_FLAG file from this deployment"
  task remove: :environment do
    flag_file = Rails.root.join('storage', 'ACTIVE_FLAG')
    
    if File.exist?(flag_file)
      # Read content before removing for logging
      content = File.read(flag_file).strip rescue "Unknown"
      File.delete(flag_file)
      puts "🗑️  Active flag removed"
      puts "📝 Previous content:"
      puts content.indent(2)
    else
      puts "ℹ️  No active flag found to remove"
    end
  end
  
  desc "Check the status of the ACTIVE_FLAG file"
  task status: :environment do
    flag_file = Rails.root.join('storage', 'ACTIVE_FLAG')
    current_host = ENV.fetch('APPLICATION_HOST', 'unknown')
    
    puts "🏁 Flag Status Check"
    puts "Host: #{current_host}"
    puts "Environment: #{Rails.env}"
    puts "Flag file: #{flag_file}"
    puts
    
    if File.exist?(flag_file)
      content = File.read(flag_file).strip
      puts "✅ Flag is PRESENT"
      puts "📝 Content:"
      puts content.indent(2)
      puts
      puts "✅ This deployment is authorized to run"
    else
      puts "❌ Flag is MISSING"
      puts
      puts "❌ This deployment is NOT authorized to run"
      puts "💡 To transfer the flag here, run:"
      puts "   ./scripts/transfer_flag.sh #{current_host}"
    end
  end
  
  desc "Force create flag (emergency use only)"
  task :force_create, [:reason] => :environment do |t, args|
    reason = args[:reason] || "Emergency override"
    
    print "⚠️  This will force create a flag, potentially allowing multiple active deployments. Continue? (y/N): "
    response = STDIN.gets.chomp.downcase
    
    unless response == 'y' || response == 'yes'
      puts "❌ Force flag creation cancelled"
      exit 1
    end
    
    Rake::Task['flag:create'].invoke("FORCE: #{reason}")
    puts "⚠️  FLAG FORCE CREATED - Use with caution!"
  end
end