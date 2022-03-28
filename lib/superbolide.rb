require "json"
require "http"
require "connection_pool"
require "superbolide/version"
require "superbolide/job"

class FooJob
  include Superbolide::Job

  def perform
    sleep(rand)
    raise "oops" if rand < 0.2
  end
end

module Superbolide
  extend self

  attr_reader :connection_pool

  @connection_pool = ConnectionPool.new(size: 5, timeout: 5) do
    uri = URI.parse(ENV["SUPERBOLIDE_URL"])
    token = uri.password || uri.user
    HTTP.persistent(uri).auth("Bearer #{token}")
  end

  def push(klass, opts = {})
    job = opts.merge(type: klass.to_s)

    connection_pool.with do |http|
      resp = http.put("/push", json: {job: job})
      payload = JSON.parse(resp.to_s)
      raise payload["error"] if resp.code != 200
      payload
    end
  end

  def info
    connection_pool.with do |http|
      resp = http.get("/info")
      payload = JSON.parse(resp.to_s)
      raise payload["error"] if resp.code != 200
      payload
    end
  end

end
