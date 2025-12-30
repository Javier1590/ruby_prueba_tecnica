# run_fetch.rb
require_relative './easy_broker_client'
require 'json'
require 'dotenv/load'

api_key = ENV['EASYBROKER_API_KEY']
raise "Define EASYBROKER_API_KEY" unless api_key && !api_key.empty?

client = EasyBrokerClient.new(api_key: api_key)

# Obtén todas las propiedades (puede tardar si hay muchas)
props = client.fetch_all_properties

# Imprime (pretty) JSON de cada propiedad; limita a 5 para no saturar
props.first(5).each do |p|
  puts JSON.pretty_generate(p)
  puts "-" * 80
end

puts "Total properties fetched: #{props.length}"
