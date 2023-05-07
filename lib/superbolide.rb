require "json"
require "http"
require "connection_pool"
require "superbolide/version"
require "superbolide/job"

module Superbolide
  extend self

  class InvalidPayloadError < StandardError; end

  attr_reader :config, :connection_pool

  CONFIG_OPTIONS = [:api_token, :api_endpoint, :queue, :concurrency, :pool_size, :pool_timeout]

  @config = Struct.new(*CONFIG_OPTIONS).new

  def configure(&block)
    new_config = @config.dup
    block.call(new_config)
    @config = new_config.freeze

    @connection_pool = ConnectionPool.new(size: config.pool_size, timeout: config.pool_timeout) do
      uri = URI.parse(config.api_endpoint)
      HTTP.persistent(uri).auth("Bearer #{config.api_token}")
    end
  end

  configure do |c|
    c.api_token = (ENV["SUPERBOLIDE_API_TOKEN"] || "").strip
    c.api_endpoint = (ENV["SUPERBOLIDE_ENDPOINT"] || "https://superbolide.io").strip
    c.queue = "default"
    c.concurrency = 10
    c.pool_size = c.concurrency + 5
    c.pool_timeout = 1
  end

end
