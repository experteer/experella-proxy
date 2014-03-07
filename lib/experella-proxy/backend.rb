module ExperellaProxy
  # The Proxies connection to the backend server
  #
  # This class will never be directly initiated by user code, but initializing gets triggered in client {Connection}
  class Backend < EventMachine::Connection

    include ExperellaProxy::Globals

    # @!visibility private
    attr_accessor :plexer, :name

    # Called by the EventMachine loop when a remote TCP connection attempt completes successfully
    #
    # Calls client {Connection} {Connection#connected} method
    #
    def connection_completed
      log.debug [@name, :conn_complete]
      @plexer.connected(@name)
      @connected.succeed
    end

    # Called by the EventMachine loop whenever data has been received by the network connection.
    # It is never called by user code. {#receive_data} is called with a single parameter,
    # a String containing the network protocol data, which may of course be binary.
    #
    # Data gets passed to client {Connection} through {Connection#relay_from_backend}
    #
    # @param data [String] Opaque response data
    def receive_data(data)
      log.debug [:receive_backend, @name]
      @plexer.relay_from_backend(@name, data)
    end

    # Buffer data for send until the connection to the backend server is established and is ready for use.
    #
    # @param data [String] data to be send to the connected backend server
    def send(data)
      log.debug [:send_backend, data]
      @connected.callback { send_data data }
    end

    # Notify upstream plexer that the backend server is done processing the request
    #
    def unbind
      log.debug [@name, :unbind]
      @plexer.unbind_backend(@name)
    end

    private

    # @private constructor, gets called by EventMachine::Connection's overwritten new method
    #
    def initialize
      @connected = EM::DefaultDeferrable.new
    end

  end
end
