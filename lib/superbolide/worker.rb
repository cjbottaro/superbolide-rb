require "thread"

module Superbolide
  module Worker
    extend(self)

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
      uri = URI.parse(ENV["SUPERBOLIDE_URL"])
      token = uri.password || uri.user
      http = HTTP.persistent(uri).auth("Bearer #{token}")

      while not @shutdown
        payload = post(http, "/fetch")
        job = payload["job"]

        next unless job

        jid = job["jid"]
        class_name = job["type"]
        ack_token = payload["ack_token"]
        job_args = job["args"] || []
        args = job_args
          .inspect
          .delete_prefix("[")
          .delete_suffix("]")

        puts "🚀 Start #{jid} #{class_name}(#{args})"
        start_time = Time.now

        begin
          job_class = Object.const_get(class_name)
          job_class.new.perform(*job_args)
        rescue Exception => e
          elapsed = (Time.now - start_time).round(3)

          post(http, "/fail", json: {
            jid: jid,
            ack_token: ack_token,
            err_type: e.class.name,
            err_msg: e.message,
            err_trace: e.backtrace.join("\n")
          })

          puts "💥 Nak #{jid} #{class_name}(#{args}) in #{elapsed}s"
        else
          elapsed = (Time.now - start_time).round(3)

          post(http, "/ack", json: {
            jid: jid,
            ack_token: ack_token
          })

          puts "🥂 Ack #{jid} #{class_name}(#{args}) in #{elapsed}s"
        end
      end
    end

    def post(http, *args)
      resp = begin
        http.post(*args)
      rescue HTTP::ConnectionError
        puts "HTTP connection error, retrying in 1s"
        sleep(1)
        retry
      end

      payload = JSON.parse(resp.to_s)

      if resp.code != 200
        puts "WARNING #{resp.code} #{payload.inspect}"
      end

      payload
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