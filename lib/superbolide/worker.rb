require "thread"
require "superbolide/api"

module Superbolide
  module Worker
    extend(self)

    @shutdown = false

    def start
      worker_threads = Superbolide.config.concurrency.times.map do
        Thread.new { run_loop }
      end

      while not @shutdown
        sleep 1
        worker_threads.each do |thread|
          thread.join unless thread.alive?
        end
      end

      worker_threads.each(&:join)
      puts "Graceful shutdown successful. Goodbye."
    end

    private def run_loop
      queue = Superbolide.config.queue

      while not @shutdown
        job = Superbolide::Api.dequeue(queue)
        next if job["empty"]

        start_time = Time.now
        ack_token  = job["ack_token"]
        class_name = job["type"]
        payload    = job["payload"]
        args       = nil        

        begin
          args = parse_args(payload)
          puts "🚀 Start #{class_name}(#{pretty_args(args)})"
          job_class = Object.const_get(class_name)
          job_class.new.perform(*args)
        rescue Exception => e
          Superbolide::Api.nak(ack_token, e)
          elapsed = (Time.now - start_time).round(2)
          puts "💥 Nak #{class_name}(#{pretty_args(args)}) in #{elapsed}s"
        else
          Superbolide::Api.ack(ack_token)
          elapsed = (Time.now - start_time).round(2)
          puts "🥂 Ack #{class_name}(#{pretty_args(args)}) in #{elapsed}s"
        end
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

    private def parse_args(payload)
      JSON.parse(payload)
    rescue JSON::ParserError
      raise Superbolide::InvalidPayloadError, "expecting JSON payload"
    end

    private def pretty_args(args)
      case args
      when String
        args
      when Array
        args.inspect[1..-2]
      when nil
        nil
      end
    end

  end
end