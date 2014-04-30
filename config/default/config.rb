# Backend Server
base_backend_port = (ENV["BASE_PORT"] || 4000).to_i
backend1_port = base_backend_port + 1
backend2_port = base_backend_port + 2

# add servers in schema, :name, :host, :port, :concurrency,
# :host and :port are required, everything else is optional though name needs to be unique!
# :accepts {"header" => regex} hash, :mangle {"header" => "string"||lambda do |header-value|}
# accepts hash can additionally use uri :port, :path, :query for more efficient comparison
# mangle hash can modify any http headers, use strings for simple replace, use lambda for logic
# accepts and mangle are optional, but care: not using accepts means the server accepts every request and backends will
# always ignore the settings of any other backend server.
# use ^((?!pattern).)*$ to negate matching

# template backend servers

backend(:name => "srv1", :host => "localhost", :port => backend1_port, :concurrency => "1000",
        :accepts => { "request_url" => "^((?!/(srv2)($|/)).)*$" }
)

backend(:name => "srv2", :host_port => "localhost:#{backend2_port}", :concurrency => "1",
        :accepts => { "request_url" => "/(srv2)($|/)" },
        :mangle => { "Host" => lambda do |host|
          if host.match(/127.0.0/)
            'localhost'
          else
            host
          end
        end
        }
)

# experimental!
# web support if used as a forward proxy. care, not all webservers accept http-proxy standard (e.g. wikimedia)
# Host and Port will be set according to Requests Host header instead of :host and :port keys.
# backend(:name => "web", :host => "0.0.0.0", :port => "80", :concurrency => "1000",
#  :accepts => {"Host" => "^((?!localhost).)*$"}
# )

require 'logger'

# set a logger. Has to support debug/info/warn/error/fatal logger functions
set_logger Logger.new($stdout)
logger.level = Logger::WARN

# set proxy servers here, listens on every host, port hash pair
# you can add one pair per call to set_proxy(hsh)
# additionally you can activate ssl with provided private_key and cert_chain files
set_proxy(:host => "localhost", :port => base_backend_port)
set_proxy(:host => "localhost", :port => base_backend_port + 443,
          :options => { :tls              => true,
                        :private_key_file => 'ssl/private/experella-proxy.key',
                        :cert_chain_file  => 'ssl/certs/experella-proxy.pem' }
)

# set the timeout in seconds. Will unbind a keep-alive connection
# if no send/receive event occured in specified seconds
set_timeout(30.0)

# provide errorpage locations. first arguument is error code, second is (html) file location in configfile folder
set_error_pages(404, "404.html")
set_error_pages(503, "503.html")

# you can log things as you want:
# set_on_event(lambda do |name,detail|
# if detail.delete(:error)
#   Experella.config.logger.error([name,detail.inspect])
# else
#   Experella.config.logger.debug([name,detail.inspect])
# end
# end)
