module ExperellaProxy
  # The proxy
  #
  # Controls the EventMachine, initializes backends from config and starts proxy servers
  class Proxy
    extend ExperellaProxy::Globals

    # Starts the Eventmachine, initializes backends in {ConnectionManager} and starts the servers
    # defined in config the proxy should listen on
    #
    # @param options [Hash] option Hash passed to the {Connection}
    # @param blk [Block] Block evaluated in each new {Connection}
    def self.start(options, &blk)

      #initalize backend servers from config
      config.backends.each do |backend|
        connection_manager.add_backend(BackendServer.new(backend[:host], backend[:port], backend))
        log.info "Initializing backend #{backend[:name]} at #{backend[:host]}:#{backend[:port]} with concurrency\
                 #{backend[:concurrency]}"
        log.info "Backend accepts: #{backend[:accepts].inspect}"
        log.info "Backend mangles: #{backend[:mangle].inspect}"
      end

      #start eventmachine
      EM.epoll
      EM.run do
        trap("TERM") { stop }
        trap("INT") { stop }

        if config.proxy.empty?
          log.fatal "No proxy host:port address configured. Stopping experella-proxy."
          return stop
        else
          config.proxy.each do |proxy|
            opts = options
            # pass proxy specific options
            unless proxy[:options].nil?
              opts = options.merge(proxy[:options])
            end
            log.info "Launching experella-proxy at #{proxy[:host]}:#{proxy[:port]} with #{config.timeout}s timeout..."
            log.info "with options: #{opts.inspect}"
            EventMachine::start_server(proxy[:host], proxy[:port],
                                       Connection, opts) do |conn|
              conn.instance_eval(&blk)
            end
          end
        end
      end
    end

    #
    # Stops the Eventmachine and terminates all connections
    #
    def self.stop
      if EM.reactor_running?
        EventMachine::stop_event_loop
      end
    end
  end
end
