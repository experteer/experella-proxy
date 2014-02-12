require 'optparse'
require 'eventmachine'
require 'http_parser.rb'
require 'experella-proxy/globals'
require 'experella-proxy/http_status_codes'
require 'experella-proxy/configuration'
require 'experella-proxy/server'
require 'experella-proxy/connection_manager'
require 'experella-proxy/backend_server'
require 'experella-proxy/connection'
require 'experella-proxy/proxy'
require 'experella-proxy/backend'
require 'experella-proxy/request'
require 'experella-proxy/response'

# Namespace Module for the Proxy Server
#
# Startup code and options parser is defined here
#
# @example startup
#   ARGV << '--help' if ARGV.empty?
#
#   options = {}
#   OptionParser.new do |opt|
#     opt.banner = "Usage: experella-proxy <command> <options> -- <application options>\n\n"
#     opt.banner << "where <applicaion options> are"
#
#     opt.on("-c", "--config=CONFIGFILE", "start server with config in given filepath") do |v|
#       options[:configfile] = File.expand_path(v)
#       ExperellaProxy.run(options)
#     end
#
#   end.parse!
#
# @see file:README.md README
# @author Dennis-Florian Herr 2014 @Experteer GmbH
module ExperellaProxy

  # Initializes ExperellaProxy's {Configuration} and {ConnectionManager}
  #
  # @param [Hash] options Hash passed to the configuration
  # @option option [String] :configfile the config filepath
  # @return [Boolean] true if successful false if NoConfigError was raised
  def self.init(options={})
    begin
    Configuration.new(options)
    rescue Configuration::NoConfigError => e
      puts e.message
      puts e.backtrace.join("\n\t")
      return false
    end
    @connection_manager = ConnectionManager.new
    true
  end

  # Creates Server object and calls {Server#run} if {ExperellaProxy#init}
  #
  # @param [Hash] options Hash passed to the configuration
  # @option option [String] :configfile the config filepath
  def self.run(options={})
    @server = Server.new(options).run if ExperellaProxy.init(options)
  end

  # Fresh restarts ExperellaProxy with same options.
  #
  # Loses all buffered data
  def self.restart
    opts = @server.options
    self.stop
    Server.new(opts).run if ExperellaProxy.init(opts)
  end

  # Stops ExperellaProxy
  #
  def self.stop
     Proxy.stop
  end

end

#startup
ARGV << '--help' if ARGV.empty?

options = {}
OptionParser.new do |opt|
  opt.banner = "Usage: experella-proxy <command> <options> -- <application options>\n\n"
  opt.banner << "where <applicaion options> are"

  opt.on("-c", "--config=CONFIGFILE", "start server with config in given filepath") do |v|
    options[:configfile] = File.expand_path(v)
    ExperellaProxy.run(options)
  end
end.parse!
