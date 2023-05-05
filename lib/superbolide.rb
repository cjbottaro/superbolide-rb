require "json"
require "http"
require "connection_pool"
require "superbolide/version"
require "superbolide/job"

module Superbolide
  extend self

  attr_reader :connection_pool

  @connection_pool = ConnectionPool.new(size: 5, timeout: 5) do
    uri = URI.parse(configuration[:api_endpoint])
    token = configuration[:api_token]
    HTTP.persistent(uri).auth("Bearer #{token}")
  end

  def configuration
    @configuration ||= begin
      api_token = (ENV["SUPERBOLIDE_API_TOKEN"] || "").strip
      api_endpoint = (ENV["SUPERBOLIDE_ENDPOINT"] || "").strip
      api_endpoint ||= "https://superbolide.io"

      {
        api_token: api_token,
        api_endpoint: api_endpoint
      }
    end
  end

  def enqueue(job)
    resp = enqueue_request(job)
    while resp.code == 429
      resp = enqueue_request(job)
    end

    JSON.parse(resp.to_s).tap do |payload|
      raise payload["error"] if resp.code != 200
    end
  end

  private def enqueue_request(job)
    connection_pool.with do |http|
      http.post("/api/enqueue", json: job)
    end
  rescue HTTP::ConnectionError
    puts "HTTP connection error, retrying in 1s"
    sleep(1)
    retry
  end

end
