module ExperellaProxy

  # static getter for the config variable
  #
  # @return [Configuration] config
  def self.config
    @config
  end

  # static setter for the config variable
  #
  # @param config [Configuration] a config object
  # @return [Configuration] config
  def self.config=(config)
    @config=config
  end
  # The Configuration loader
  #
  # The config specifies following DSL options
  #
  # backend
  #  Takes an options hash defining a backend_server, see {BackendServer}
  #
  # set_logger
  #  specifies the Logger used by the program. The Logger must support debug/info/warn/error/fatal functions
  #
  # set_proxy
  #  Add proxy as Hash with :host => "string-ip/domain" and :proxy => Fixnum
  #  The proxy will listen on every host:port hash added with this function.
  #
  # set_timeout
  #  Time as float when an idle persistent connection gets closed (no receive/send events occured)
  #
  # set_error_pages
  #  Add html error-pages to the proxy, requires 2 arguments
  #  1st arg: the error code as Fixnum
  #  2nd arg: path to an error page html file relative to the config file directory
  #  Currently 404 and 503 error codes are supported
  #
  class Configuration

    # Error raised if the Config couldn't be load successfully
    #
    # Currently only raised if config filepath is invalid
    class NoConfigError < StandardError

    end

    attr_reader :logger, :proxy, :timeout, :backends, :error_pages

    require 'logger'

    # The Configuration
    #
    # @param [Hash] options
    # @option options [String] :configfile the config filepath
    def initialize(options={})
      @backends=[]
      @proxy=[]
      @error_pages = {404 => "", 503 => ""}
      default_options={:timeout => 15.0, :logger => Logger.new($stdout)}
      options=options.inject({}){|memo,(k,v)| memo[k.to_sym] = v; memo}
      options=default_options.merge(options)
      options.each do |k,v|
        self.instance_variable_set("@#{k}",v)
      end
      read_config_file(@configfile) if @configfile
      ExperellaProxy.config=self
    end

    # Return filenames fullpath relative to configfile directory
    #
    # @param filename [String] the filename
    # @return [String] full filepath
    def join_config_path(filename)
      File.expand_path(File.join(File.dirname(@configfile), filename))
    end

    # Opens the given config file and evaluates it's contents DSL
    #
    # @param configfile [String] the config filepath
    # @return [Boolean] true on success, false if file can't be found
    def read_config_file(configfile)
      if !File.exists?(configfile)
        puts "error reading #{configfile}"
        raise NoConfigError.new("unable to read config file #{configfile}")
      end
      content=File.read(configfile)
      instance_eval(content)
      true
    end

    #DSL:

    # Adds a {BackendServer} specified in the config file to {#backends}
    # It allows some syntactic sugar to pass :host_port as an abbrev of host and port keys separated by ':'.
    # @see {BackendServer#initialize}
    #
    # @param backend_options [Hash] backends option hash

    def backend(backend_options)
      host_port=backend_options.delete(:host_port)
      if host_port
        host,port = host_port.split(":")
        backend_options[:host] = host
        backend_options[:port] = port
      end
      @backends << backend_options
    end

    # Sets the {Connection} timeout specified in the config file
    #
    # @param to [Float] timeout as float
    def set_timeout(to)
      @timeout=to
    end

    # Sets the global Logger object specified in the config file
    #
    # Logger can be any object that responds to Ruby Loggers debug, info, warn, error, fatal functions
    #
    # @param logger [Logger] the logger object
    def set_logger(logger)
      @logger=logger
    end

    # Adds a Proxy specified in the config file to {#proxy}
    #
    # Multiple proxies can be added with multiple calls. Needs a Hash containing :host => "domain/ip", :port => fixnum
    #
    # @param proxy [Hash] proxy Hash with :host => "domain/ip", :port => fixnum, :options => options
    # @option options [Boolean] :tls true if proxy uses TLS encryption
    # @option options [String] :private_key_file file path to ssl private_key_file relative to config file directory
    # @option options [String] :cert_chain_file file path to ssl cert_chain_file relative to config file directory
    def set_proxy(proxy)
      if proxy[:options] && proxy[:options][:tls]
        proxy[:options][:private_key_file] = join_config_path(proxy[:options][:private_key_file])
        proxy[:options][:cert_chain_file] = join_config_path(proxy[:options][:cert_chain_file])
      end
      @proxy << proxy
    end

    # Loads the Errorpages specified in the config file
    #
    # currently 404 and 503 errors are supported
    #
    # @param key [Fixnum] HTTP Error code
    # @param page_path [String] page_path relative to config file directory
    def set_error_pages(key, page_path)
      @error_pages[key] = File.read(join_config_path(page_path))
    end

  end
end
