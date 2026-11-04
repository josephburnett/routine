namespace :api_tokens do
  desc "Create an MCP API token: bin/rails 'api_tokens:create[user_name,token_name]'"
  task :create, [ :user, :name ] => :environment do |_, args|
    user = User.find_by!(name: args[:user])
    token, plain = ApiToken.issue!(user: user, name: args[:name].presence || "mcp")
    puts "Token ##{token.id} (#{token.name}) for #{user.name}:"
    puts plain
    puts "Store it now; it can't be shown again."
  end

  desc "List MCP API tokens"
  task list: :environment do
    ApiToken.includes(:user).order(:id).each do |t|
      status = t.revoked_at ? "revoked #{t.revoked_at}" : "active, last used #{t.last_used_at || 'never'}"
      puts "##{t.id} #{t.user.name} #{t.name} (#{status})"
    end
  end

  desc "Revoke an MCP API token: bin/rails 'api_tokens:revoke[id]'"
  task :revoke, [ :id ] => :environment do |_, args|
    ApiToken.find(args[:id]).revoke!
    puts "Revoked token ##{args[:id]}"
  end
end
