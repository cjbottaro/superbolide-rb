module Superbolide
  module Api
    extend(self)

    def enqueue(queue, type, payload, options = {})
      post("/api/enqueue",
        queue: queue,
        type: type,
        payload: payload,
        uid: options[:uid],
        tags: options[:tags]
      )
    end

    def dequeue(queue)
      post("/api/dequeue", queue: queue)
    end

    def ack(token)
      post("/api/ack", ack_token: token)
    end

    def nak(token, e)
      post("/api/nak",
        ack_token: token,
        err_type: e.class.name,
        err_msg: e.message,
        err_trace: e.backtrace.join("\n")
      )
    end

    private def post(path, json)
      resp = do_post(path, json)
      while resp.code == 429
        puts "Superbolide rate limit hit, retrying now"
        resp.flush
        resp = do_post(path, json)
      end

      JSON.parse(resp.to_s).tap do |payload|
        raise payload["error"] if resp.code != 200
      end
    end

    private def do_post(path, json)
      Superbolide.connection_pool.with do |http|
        http.post(path, json: json)
      end
    rescue HTTP::ConnectionError
      puts "Superbolide connection error, retrying in 1s"
      sleep(1)
      retry
    rescue ConnectionPool::TimeoutError
      puts "Superbolide connection pool timeout, retrying now"
      retry
    end

  end
end