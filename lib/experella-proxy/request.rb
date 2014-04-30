module ExperellaProxy
  #
  # Request is used to store incoming (HTTP) requests and parsed data
  #
  # Every Request belongs to a client {Connection}
  #
  class Request

    include ExperellaProxy::Globals

    attr_accessor :keep_alive, :chunked
    attr_reader :conn, :header, :uri, :response

    # The constructor
    #
    # @param conn [Connection] Connection the request belongs to
    def initialize(conn)
      @conn = conn
      @header = {}
      @chunked = false # if true the parsed body will be chunked
      @uri = {} #contains port, path and query information for faster backend selection
      @keep_alive = true
      @send_buffer = String.new
      @response = Response.new(self)
    end

    # Adds data to the request object
    #
    # data must be formatted as string
    #
    # @param str [String] data as string
    def <<(str)
      @send_buffer << str
    end

    # Adds a hash with uri information to {#uri}
    #
    # duplicate key values will be overwritten with hsh values
    #
    # @param hsh [Hash] hash with keys :port :path :query containing URI information
    def add_uri(hsh)
      @uri.update(hsh)
      event(:request_add_uri, :uri => hsh)
    end

    # Returns the data in send_buffer and empties the send_buffer
    #
    # @return [String] data to send
    def flush
      @send_buffer.slice!(0, @send_buffer.length)
    end

    # Returns if the send_buffer is flushed? (empty)
    #
    # @return [Boolean]
    def flushed?
      @send_buffer.empty?
    end

    # Reconstructs modified http request in send_buffer
    #
    # Reconstructed request must be a valid request according to the HTTP Protocol
    #
    # First Header after Startline will always be "Host: ", after that order is determined by {#header}.each
    #
    def reconstruct_header
      #split send_buffer into header and body part
      buf = @send_buffer.split(/\r\n\r\n/, 2) unless flushed?
      @send_buffer = ""
      #start line
      @send_buffer << @header[:http_method] + ' '
      @send_buffer << @header[:request_url] + ' '
      @send_buffer << "HTTP/1.1\r\n"
      @send_buffer << "Host: " + @header[:Host] + "\r\n" #add Host first for better header readability
      #header fields
      @header.each do |key, value|
        unless  key == :http_method || key == :request_url || key == :http_version || key == :Host #exclude startline parameters
          @send_buffer << key.to_s + ": "
          if value.is_a?(Array)
            @send_buffer << value.shift
            until value.empty? do
              @send_buffer << "," + value.shift
            end
          else
            @send_buffer << value
          end
          @send_buffer << "\r\n"
        end
      end
      @send_buffer << "\r\n"
      #reconstruction complete
      @send_buffer << buf[1] unless buf.nil? #append buffered body
      event(:request_reconstruct_header, :data => @send_buffer)
    end

    # Adds a hash to {#header}
    #
    # symbolizes hsh keys, duplicate key values will be overwritten with hsh values
    #
    # @param hsh [Hash] hash with HTTP header Key:Value pairs
    def update_header(hsh)
      hsh = hsh.inject({}) { |memo, (k, v)| memo[k.to_sym] = v; memo }
      @header.update(hsh)
    end
  end
end