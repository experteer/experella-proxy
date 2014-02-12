module ExperellaProxy
  # The server starts the {Proxy} and provides callbacks/block hooks for client {Connection}s
  class Server
    include ExperellaProxy::Globals

    # Constructor
    #
    # @param options [Hash] options Hash passed to the proxy
    def initialize(options)
      @options=options
    end

    attr_reader :options

    # Runs the proxy server with given options
    #
    # Opens a block passed to every {Connection}
    #
    # You can add logic to
    #
    # {Connection#connected} in on_connect
    # {Connection#receive_data} in on_data, must return data
    # {Connection#relay_from_backend} in on_response, must return resp
    # {Connection#unbind_backend} in on_finish
    # {Connection#unbind} in on_unbind
    #
    def run

      Proxy.start(options = {}) do |conn|

        log.info msec + "new Connection @" + signature.to_s

        # called on successful backend connection
        # backend is the name of the connected server
        conn.on_connect do |backend|

        end

        # modify / process request stream
        # and return modified data
        conn.on_data do |data|
          data
        end

        # modify / process response stream
        # and return modified response
        conn.on_response do |backend, resp|
          resp
        end

        # termination logic
        conn.on_finish do |backend|

        end

        # called if client terminates connection
        # or timeout occurs
        conn.on_unbind do

        end
      end

    end

  end

end

