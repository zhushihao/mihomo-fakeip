require 'yaml'

config_path, secrets_path = ARGV
abort 'Usage: bmos-subscriptions.rb CONFIG LOCAL_YAML' unless secrets_path
config = YAML.load_file(config_path)
secrets = YAML.load_file(secrets_path)
(config['proxy-providers'] || {}).each do |name, provider|
  next unless %w[vip1 vip2 vip3].include?(name)
  url = secrets[name]
  abort "Missing local subscription: #{name}" unless url.is_a?(String) && url.start_with?('https://')
  provider['url'] = url
end
File.open(config_path, 'w', 0600) { |file| file.write(YAML.dump(config)) }
