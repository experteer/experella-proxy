require 'uri'

module ExperellaProxy
  # The proxies TCP Connection to the client
  #
  # Responsible for parsing and buffering the clients http requests,
  # connecting to the backend server, sending data to the backend server and returning responses to the client.
  #
  # See EventMachine::Connection documentation for more information
  #
  # @see http://eventmachine.rubyforge.org/EventMachine/Connection.html EventMachine::Connection
  class Connection < EventMachine::Connection
    include ExperellaProxy::Globals

    # Used to pass an optional block to the connection which will be executed when the {#connected} event occurs
    #
    # @example
    #   # called on successful backend connection
    #   # backend is the name of the connected server
    #   conn.on_connect do |backend|
    #
    #   end
    #
    # @param blk [Block] a block to be executed
    def on_connect(&blk)
      @on_connect = blk
    end

    # Used to pass an optional block to the connection which will be executed when the {#receive_data} event occurs
    #
    # @example
    #     # modify / process request stream
    #     # and return modified data
    #     conn.on_data do |data|
    #       data
    #     end
    #
    # @param blk [Block] a block to be executed
    # @return [String] the modified data
    def on_data(&blk)
      @on_data = blk
    end

    # Used to pass an optional block to the connection which will be executed when the {#relay_from_backend} event occurs
    #
    # @example
    #     # modify / process response stream
    #     # and return modified response
    #     # backend is the name of the connected server
    #     conn.on_response do |backend, resp|
    #       resp
    #     end
    #
    # @param blk [Block] a block to be executed
    # @return [String] the modified response
    def on_response(&blk)
      @on_response = blk
    end

    # Used to pass an optional block to the connection which will be executed when the {#unbind_backend} event occurs
    #
    # @example
    #     # termination logic
    #     # backend is the name of the connected server
    #     conn.on_finish do |backend|
    #
    #     end
    #
    # @param blk [Block] a block to be executed
    def on_finish(&blk)
      @on_finish = blk
    end

    # Used to pass an optional block to the connection which will be executed when the {#unbind} event occurs
    #
    # @example
    #     # called if client terminates connection
    #     # or timeout occurs
    #     conn.on_unbind do
    #
    #     end
    #
    # @param blk [Block] a block to be executed
    def on_unbind(&blk)
      @on_unbind = blk
    end

    # calls EventMachine close_connection_after_writing method with 1 tick delay
    # waits 1 tick to make sure reactor i/o does not have unnecessary loop delay
    def close
      @unbound = true
      EM.next_tick(method(:close_connection_after_writing))
      event(:connection_close, :signature => @signature, :msec => msec)
    end

    # Connects self to a BackendServer object
    #
    # Any request mangling configured in {BackendServer#mangle} will be done here
    #
    # Method provides additional support for BackendServer's named "web".
    # Host and Port will be determined through the Request instead of BackendServer settings.
    #
    # @param backend [BackendServer] the BackendServer object
    def connect_backendserver(backend)
      @backend = backend
      connection_manager.free_connection(self)
      # mangle http headers
      mangle
      # reconstruct the request header
      get_request.reconstruct_header
      # special web support for unknown hosts
      if @backend.name.eql?("web")
        xport = get_request.header[:Host].match(/:[0-9]+/)
        if xport.nil? || xport.to_s.empty?
          xport = "80"
        else
          xport = xport.to_s.gsub(/:/, "")
        end
        xhost = get_request.header[:Host].gsub(":#{xport}", "")
        server(@backend.name, :host => xhost, :port => xport)
      else
        server(@backend.name, :host => @backend.host, :port => @backend.port)
      end
    end

    # Called by backend connections when the remote TCP connection attempt completes successfully.
    #
    # {#on_connect} block will be executed here
    #
    # This method triggers the {#relay_to_server} method
    #
    # @param name [String] name of the Server used for logging
    def connected(name)
      @on_connect.call(name) if @on_connect
      event(:connection_connected, :msec => msec, :signature => @signature.to_s, :name => name)
      relay_to_server
    end

    # Used for accessing the connections first request
    #
    # Buffered requests must not be handled before first in done
    #
    # @return [Request] the Request to be handled
    def get_request
      @requests.first
    end

    # Called by the EventMachine loop whenever data has been received by the network connection.
    # It is never called by user code. {#receive_data} is called with a single parameter,
    # a String containing the network protocol data, which may of course be binary.
    #
    # Data gets passed to the specified {#on_data} block first
    # Then data gets passed to the parser and the {#relay_to_server} method gets fired
    #
    # On Http::Parser::Error a 400 Bad Request error send to the client and the Connection will be closed
    #
    # @param data [String] Opaque incoming data
    def receive_data(data)
      event(:connection_receive_data_start, :msec => msec, :data => data)
      data = @on_data.call(data) if @on_data
      begin
        @request_parser << data
      rescue Http::Parser::Error
        event(:connection_receive_data_parser_error, :msec => msec, :signature => @signature, :error => true)
        # on error unbind request_parser object, so additional data doesn't get parsed anymore
        #
        # assigning a string to the parser variable, will cause incoming data to get buffered
        # imho this is a better solution than adding a condition for this rare error case
        @request_parser = ""
        send_data "HTTP/1.1 400 Bad Request\r\nVia: 1.1 experella\r\nConnection: close\r\n\r\n"
        close
      end

      event(:connection_receive_data_stop, :msec => msec, :data => data)
      relay_to_server
    end

    # Called by {Backend} connections.
    # Relays data from backend server to the client
    #
    # {#on_response} block will be executed here
    #
    # @param name [String] name of the Server used for logging
    # @param data [String] opaque response data
    def relay_from_backend(name, data)
      event(:connection_relay_from_backend, :msec => msec, :data => data, :name => name)
      @got_response = true
      data = @on_response.call(name, data) if @on_response
      get_request.response << data
    end

    # Initialize a {Backend} connection
    #
    # Can connect to host:port server address
    #
    # @param name [String] name of the Server used for logging
    # @param opts [Hash] Hash containing connection parameters
    def server(name, opts)
      srv = EventMachine.bind_connect(opts[:bind_host], opts[:bind_port], opts[:host], opts[:port], Backend) do |c|
        c.name = name
        c.plexer = self
      end

      @server = srv
    end

    #
    # ip, port of the connected client
    #
    def peer
      @peer ||= begin
        peername = get_peername
        peername ? Socket.unpack_sockaddr_in(peername).reverse : nil
      end
    end

    # Called by the event loop immediately after the network connection has been established,
    # and before resumption of the network loop.
    # This method is generally not called by user code, but is called automatically
    # by the event loop. The base-class implementation is a no-op.
    # This is a very good place to initialize instance variables that will
    # be used throughout the lifetime of the network connection.
    #
    # This is currently used to initiate start_tls on @options[:tls] enabled
    #
    #
    # @see #connection_completed
    # @see #unbind
    # @see #send_data
    # @see #receive_data
    def post_init
      if @options[:tls]
        event(:connection_tls_handshake_start, :msec => msec, :signature => @signature)
        start_tls(:private_key_file => @options[:private_key_file], :cert_chain_file => @options[:cert_chain_file], :verify_peer => false)
      end
    end

    #
    # ip, port of the local server connect
    #
    def sock
      @sock ||= begin
        sockname = get_sockname
        sockname ? Socket.unpack_sockaddr_in(sockname).reverse : nil
      end
    end

    # Called by EventMachine when the SSL/TLS handshake has been completed, as a result of calling start_tls to
    # initiate SSL/TLS on the connection.
    #
    # This callback exists because {#post_init} and connection_completed are not reliable for indicating when an
    # SSL/TLS connection is ready to have its certificate queried for.
    def ssl_handshake_completed
      event(:connection_tls_handshake_stop, :msec => msec, :signature => @signature)
    end

    # Called by backend connections whenever their connection is closed.
    # The close can occur because the code intentionally closes it
    # (using #close_connection and #close_connection_after_writing), because
    # the remote peer closed the connection, or because of a network error.
    #
    # Therefor connection errors, reconnections and queues need to be handled here
    #
    # {#on_finish} block will be executed here
    #
    # @param name [String] name of the Server used for logging
    def unbind_backend(name)
      event(:connection_unbind_backend, :msec => msec, :signature => @signature, :response => @got_response)

      if @on_finish
        @on_finish.call(name)
      end

      @server = nil

      # if backend responded or client unbound connection (timeout probably triggers this too)
      if @got_response || @unbound
        event(:connection_unbind_backend_request_done,
              :msec => msec,
              :signature => @signature,
              :size => @requests.size, :keep_alive => get_request.keep_alive.to_s)

        unless get_request.keep_alive
          close
          event(:connection_unbind_backend_close, :msec => msec, :signature => @signature)
        end
        @requests.shift # pop first element,request is done
        @got_response = false # reset response flag

        # free backend server and connect to next conn if matching conn exists
        unless @backend.nil?
          connect_next
        end

        # check if queued requests find a matching backend
        unless @requests.empty? || @unbound
          # try to dispatch first request to backend
          dispatch_request
        end
      else
        # handle no backend response here
        event(:connection_unbind_backend_error, :msec => msec, :error => true, :error_code => 503)
        error_page = "HTTP/1.1 503 Service unavailable\r\nContent-Length: #{config.error_pages[503].length}\r\nContent-Type: text/html;charset=utf-8\r\nConnection: close\r\n\r\n"
        unless get_request.header[:http_method].eql? "HEAD"
          error_page << config.error_pages[503]
        end
        send_data error_page

        close
      end
    end

    # Called by the EventMachine loop whenever the client connection is closed.
    # The close can occur because the code intentionally closes it
    # (using #close_connection and #close_connection_after_writing), because
    # the remote peer closed the connection, or because of a network error.
    #
    # This is used to clean up associations made to the connection object while it was open.
    #
    # {#on_unbind} block will be executed here
    #
    def unbind
      @unbound = true
      @on_unbind.call if @on_unbind

      event(:connection_unbind_client, :msec => msec, :signature => @signature)
      # lazy evaluated. if first is true, second would cause a nil-pointer!
      unless @requests.empty? || get_request.flushed? # what does this mean?
        # log.debug [msec, @requests.inspect]
      end
      # delete conn from queue if still queued
      connection_manager.free_connection(self)

      # reconnect backend to new connection if this has not happened already
      unless @backend.nil?
        connect_next
      end
      # terminate any unfinished backend connections
      unless @server.nil?
        @server.close_connection_after_writing
      end
    end

  private

    # @private constructor, gets called by EventMachine::Connection's overwritten new method
    # Initializes http parser and timeout_timer
    #
    # @param options [Hash] options Hash passed to the connection
    def initialize(options)
      @options = options
      @backend = nil
      @server = nil
      @requests = [] # contains request objects
      @unbound = false
      @got_response = false
      @request_parser = Http::Parser.new
      init_http_parser
      timeout_timer
      @start = Time.now
    end

    # checks if the free backend matches any queued connection
    # if there is a match, fire connection event to that connection
    #
    # @note DeHerr: imho ugly, initiating anothers connection backend from a connection feels just wrong
    # did this for testability. 27.11.2013
    #
    def connect_next
      # free backend server and connect to next conn if matching conn exists
      next_conn = connection_manager.free_backend(@backend)
      unless next_conn.nil?
        next_conn.connect_backendserver(@backend)
      end
      @backend = nil
    end

    # Tries to dispatch the connections first request to a BackendServer object. Usually this should not be called
    # more than once per request.
    #
    # connects to the backend if a BackendServer object is available
    #
    # logs if the connection got queued
    #
    # sends a 404 Error to client if no registered BackendServer matches the request
    def dispatch_request
      backend = connection_manager.backend_available?(get_request)

      if backend.is_a?(BackendServer)
        event(:connection_dispatch, :msec => msec, :type => :direct)
        connect_backendserver(backend)
      elsif backend == :queued
        event(:connection_dispatch, :msec => msec, :type => :queued)
      else
        event(:connection_dispatch, :msec => msec, :type => :not_found, :error => true, :error_code => 404)
        error_page = "HTTP/1.1 404 Not Found\r\nContent-Length: #{config.error_pages[404].length}\r\nContent-Type: text/html;charset=utf-8\r\nConnection: close\r\n\r\n"
        unless get_request.header[:http_method].eql? "HEAD"
          error_page << config.error_pages[404]
        end
        send_data error_page
        close
      end
    end

    # initializes http parser callbacks and blocks
    def init_http_parser
      @request_parser.on_message_begin = proc do
        @requests.push(Request.new(self))
        # this log also triggers if client sends new keep-alive request before backend was unbound
        event(:connection_http_parser_start, :msec => msec, :pipelined => (@requests.length > 1))
      end

      # called when request headers are completely parsed (first \r\n\r\n triggers this)
      @request_parser.on_headers_complete = proc do |h|
        event(:connection_http_parser_headers_complete_start, :msec => msec, :signature => @signature, :request_path => @request_parser.request_url, :host => h["Host"])
        request = @requests.last

        # cache if client wants persistent connection
        if @request_parser.http_version[0] == 1 && @request_parser.http_version[1] == 0
          request.keep_alive = false unless h["Connection"].to_s.downcase.eql? "keep-alive"
        else
          request.keep_alive = false if h["Connection"].to_s.downcase.include? "close"
        end
        request.update_header(:Connection => "close") # update Connection header to close for backends

        # if there is a transfer-encoding, stream the message as Transfer-Encoding: chunked to backends
        unless h["Transfer-Encoding"].nil?
          h.delete("Content-Length")
          request.chunked = true
          request.update_header(:"Transfer-Encoding" => "chunked")
        end

        # remove all hop-by-hop header fields
        unless h["Connection"].nil?
          if h["Connection"].is_a?(String)
            h.delete(h["Connection"])
          else
            h["Connection"].each do |s|
              h.delete(s)
            end
          end
        end
        HOP_HEADERS.each do |s|
          h.delete(s)
        end

        via = h.delete("Via")
        if via.nil?
          via = "1.1 experella"
        else
          via += ", 1.1 experella"
        end
        request.update_header(:Via => via)

        request.update_header(h)
        request.update_header(:http_version => @request_parser.http_version)
        request.update_header(:http_method => @request_parser.http_method) # for requests
        request.update_header(:request_url => @request_parser.request_url)
        if @request_parser.request_url.include? "http://"
          u = URI.parse(@request_parser.request_url)
          request.update_header(:Host => u.host)
          event(:connection_http_parser_headers_complete_absolute_host, :msec => msec, :signature => @signature, :host => u.host)
        else
          u = URI.parse("http://" + h["Host"] + @request_parser.request_url)
        end

        request.add_uri(:port => u.port, :path => u.path, :query => u.query)

        # try to connect request to backend
        # but only try to connect if this (.last) equals (.first), true at length == 1
        # according to http-protocol requests must always be handled in order.
        if @requests.length == 1
          dispatch_request
        end

        event(:connection_http_parser_headers_complete_stop, :msec => msec, :requests => @requests.size)
      end

      @request_parser.on_body = proc do |chunk|
        request = @requests.last
        if request.chunked
          # add hexadecimal chunk size
          request << chunk.size.to_s(16)
          request << "\r\n"
          request << chunk
          request << "\r\n"
        else
          request << chunk
        end
      end

      @request_parser.on_message_complete = proc do
        request = @requests.last
        if request.chunked
          # add closing chunk
          request << "0\r\n\r\n"
        end
      end
    end

    # Mangles http headers based on backend specific mangle configuration
    #
    def mangle
      unless @backend.mangle.nil?
        @backend.mangle.each do |k, v|
          if v.respond_to?(:call)
            get_request.update_header(k => v.call(get_request.header[k]))
          else
            get_request.update_header(k => v)
          end
        end
      end
    end

    # This method sends the first requests send_buffer to the backend server, if
    # any backend is set and there is request data to dispatch
    #
    # Request header will be reconstructed here before dispatch
    #
    # If the backend server is not yet connected, data is already buffered to be sent when the connection gets established
    #
    def relay_to_server
      if @backend && !@requests.empty? && !get_request.flushed? && @server
        # save some memory here if logger isn't set on debug
        data = get_request.flush
        @server.send_data data
        event(:connection_relay_to_server, :msec => msec, :signature => @signature, :requests => @requests.size,
                              :flushed => get_request.flushed?, :server_set => !!@server, :data => data)
      else
        event(:connection_relay_to_server, :msec => msec, :signature => @signature, :requests => @requests.size,
                    :flushed => get_request.flushed?, :server_set => !!@server, :data => nil)
      end
    end

    # returns milliseconds since connection startup as string
    def msec
      (((Time.now.tv_sec - @start.tv_sec) * 1000) + ((Time.now.tv_usec - @start.tv_usec) / 1000.0)).to_s + "ms: "
    end

    # starts the timeout timer and closes connection if timeout was exceeded
    def timeout_timer
      timer = EventMachine::PeriodicTimer.new(1) do
        if get_idle_time.nil?
          timer.cancel
        elsif get_idle_time > config.timeout
          event(:connection_timeout, :msec => msec, :signature => @signature)
          timer.cancel
          close
        end
      end
    end
  end
end
