require "thread"

module Superbolide
  module Worker
    extend(self)

    class RateLimitError < StandardError; end

    @shutdown = false

    def start(options)
      @options = options

      worker_threads = options[:concurrency].times.map do
        Thread.new { run_loop }
      end

      worker_threads.each(&:join)
      puts "Graceful shutdown successful, bye!"
    end

    private def run_loop
      api_endpoint = Superbolide.configuration[:api_endpoint]
      api_token = Superbolide.configuration[:api_token]

      uri = URI.parse(api_endpoint)
      http = HTTP.persistent(uri).auth("Bearer #{api_token}")

      while not @shutdown
        resp = begin
          http.post("/api/dequeue", json: {queue: "default"})
        rescue HTTP::ConnectionError
          puts "HTTP connection error, retrying in 1s"
          sleep(1)
          next
        end

        if resp.code == 429
          resp.flush
          puts "Rate limit exceeded, retrying in 1s"
          sleep(1)
          next
        end

        job = JSON.parse(resp.to_s)

        if job["empty"]
          next
        end

        ack_token  = job["ack_token"]
        class_name = job["type"]
        payload    = job["payload"]

        args = begin
          JSON.parse(payload)
        rescue JSON::ParserError
          post(http, "/api/nak", json: {
            ack_token: ack_token,
            err_type: "InvalidPayloadError",
            err_msg: "expecting JSON payload"
          })
          puts "💥 Nak #{class_name} invalid payload"
          next
        end

        puts "🚀 Start #{class_name}(#{format_args(args)})"
        start_time = Time.now

        begin
          job_class = Object.const_get(class_name)
          job_class.new.perform(*args)
        rescue Exception => e
          elapsed = (Time.now - start_time).round(3)

          post(http, "/api/nak", json: {
            ack_token: ack_token,
            err_type: e.class.name,
            err_msg: e.message,
            err_trace: e.backtrace.join("\n")
          })

          puts "💥 Nak #{class_name}(#{format_args(args)}) in #{elapsed}s"
        else
          elapsed = (Time.now - start_time).round(3)

          post(http, "/api/ack", json: {
            ack_token: ack_token
          })

          puts "🥂 Ack #{class_name}(#{format_args(args)}) in #{elapsed}s"
        end
      end
    end

    def format_args(args)
      case args
      when String
        args
      when Array
        args.inspect[1..-2]
      end
    end

    def post(http, *args)
      begin
        resp = http.post(*args)
        if resp.code == 429
          resp.flush
          raise RateLimitError
        end
        JSON.parse(resp.to_s)
      rescue HTTP::ConnectionError
        puts "HTTP connection error, retrying in 1s"
        sleep(1)
        retry
      rescue RateLimitError
        puts "Rate limit exceeded, retrying in 1s"
        sleep(1)
        retry
      end
    end

    def stop
      if not @shutdown
        puts "Attempting graceful shutdown..."
        @shutdown = true
      else
        puts "Exiting immediately"
        exit(1)
      end
    end

  end
end