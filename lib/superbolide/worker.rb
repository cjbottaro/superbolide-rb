require "thread"

module Superbolide
  module Worker
    extend(self)

    @shutdown = false

    def start(options)
      worker_threads = options[:concurrency].times.map do
        Thread.new do
          while not @shutdown
            payload = post("/fetch")
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

              post("/fail", json: {
                jid: jid,
                ack_token: ack_token,
                err_type: e.class.name,
                err_msg: e.message,
                err_trace: e.backtrace.join("\n")
              })

              puts "💥 Nak #{jid} #{class_name}(#{args}) in #{elapsed}s"
            else
              elapsed = (Time.now - start_time).round(3)

              post("/ack", json: {
                jid: jid,
                ack_token: ack_token
              })

              puts "🥂 Ack #{jid} #{class_name}(#{args}) in #{elapsed}s"
            end
          end
        end
      end

      worker_threads.each(&:join)
      puts "Graceful shutdown successful, bye!"
    end

    def post(*args)
      resp = begin
        Superbolide.connection_pool.with{ |http| http.post(*args) }
      rescue HTTP::ConnectionError
        puts "connection error, retrying in 1s"
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