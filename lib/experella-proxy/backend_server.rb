module ExperellaProxy

  # BackendServer objects contain information on available BackendServers
  #
  # Accepts Requests based on Request header information and it's message_matcher
  #
  # See {#initialize}
  class BackendServer

    attr_accessor :host, :port, :concurrency, :workload, :name
    attr_reader :message_matcher, :mangle

    # Constructor of the BackendServer
    #
    # required keys
    #
    #     :host         Host address of the Server, can be IP or domain
    #     :port         Port of the Server, Integervalue as String
    #
    # optional keys
    #
    #     :name         Name of the Server used in the Logger and Cashing, String
    #                   Will default to #{host}:#{port} but needs to be unique, though theoretical there can be
    #                   multiple servers with the same host:port value pair!
    #
    #     :concurrency  max Number of concurrent connections, Integervalue as String. Default is 1
    #
    #     :accepts      Hash containing keys matching HTTP headers or URI :path, :port, :query
    #                   Values are Regexp as Strings or as Regex, use ^((?!pattern).)*$ to negate matching
    #                   Care: Will match any Header/value pairs not defined in the accepts Hash
    #
    #     :mangle       Hash containing keys matching HTTP headers. Values can be callable block or Strings
    #                   Mangle modifies the header value based on the given block or replaces the header value with the String
    #
    # mangle is applied in {Connection#connect_backendserver}
    #
    # @param host [String] host domain-URL oder IP
    # @param port [String] port as string
    # @param [Hash] options
    # @option options [String] :name name used in logs and for storage. will use Host:Port if no name is specified
    # @option options [String] :concurrency concurrency. will use 1 as default
    # @option options [Hash|Proc] :accepts  message_pattern that will be converted to a message_matcher or an arbitrary message_matcher as proc
    #   Empty Hash is default
    # @option options [Hash] :mangle Hash which can modify request headers. Keys get symbolized. nil is default
    def initialize(host, port, options = {})
      @host = host #host URL as string
      @port = port #port as string
      @name = options[:name] || "#{host}:#{port}"
      if options[:concurrency].nil?
        @concurrency = 1
      else
        @concurrency = options[:concurrency].to_i
      end
      @workload = 0

      make_message_matcher(options[:accepts])

      #mangle can be nil
      @mangle = options[:mangle]
                   #convert keys to symbols to match request header keys
      @mangle = @mangle.inject({}) { |memo, (k, v)| memo[k.to_sym] = v; memo } unless @mangle.nil?
    end

    # compares Backend servers message_matcher to request object
    #
    # @param request [Request] a request object
    # @return [Boolean] true if BackendServer accepts the Request, false otherwise
    def accept?(request)
      res=@message_matcher.call(request)
      #puts "#{name} #{request.header['request_url']} #{res}"
      res
    end

    # Makes a message matching block from the message_pattern.
    #
    # @param obj [Hash|Proc] hash containing a message_pattern that will be converted to a message_matcher proc or an arbitrary own message_matcher
    def make_message_matcher(obj)
      @message_matcher =if obj.respond_to?(:call)
        obj
      else
        #precompile message pattern keys to symbols and values to regexp objects
        keys = (obj||{}).inject({}) { |memo, (k, v)| memo[k.to_sym] = Regexp.new(v); memo }
        lambda do |request| #TODO: ugly!
          ret=true
          keys.each do |key, pattern|
            #use uri for :port :path and :query keys
            if key == :port || key == :path || key == :query
              ret=false unless request.uri[key] && request.uri[key].match(pattern)
            else #use headers
              ret=false unless request.header[key] && request.header[key].match(pattern)
            end
            break unless ret #stop as soon as possible
          end
          ret
        end #lambda
      end
    end
  end
end
