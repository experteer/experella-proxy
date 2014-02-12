require 'logger'

request_part = "oneroute|anotherpath"

backend( :name => "experella1", :host => "127.0.0.10", :port => "7654", :concurrency => "1",
  :accepts => {"Host" => "experella", "request_url" => "^((?!/(#{request_part})($|/)).)*$"}
)

backend( :name => "experella2", :host => "127.0.0.10", :port => "7654", :concurrency => "2",
         :accepts => {"Host" => "experella", "request_url" => "^((?!/(#{request_part})($|/)).)*$"}
)

backend( :name => "exp proxy", :host => "127.0.0.11", :port => "7655", :concurrency => "1",
  :accepts => {"Host" => "experella", "request_url" => "/(#{request_part})($|/)"}
)

backend( :name => "web", :host => "0.0.0.0", :port => "80", :concurrency => "1000",
  :accepts => {"Host" => "^((?!(experella|127)).)*$"}
)

# don't forget EM-HTTP-Request (used in experella-proxy specs) default timeout is 10.0
set_timeout 6.0

set_proxy(:host => "127.0.0.1", :port => 6896)
set_proxy(:host => "127.0.0.2", :port => 7315)

# little cheating with join_config_path method :)
set_logger Logger.new(File.open(join_config_path("spec.log"), "a+"))
logger.level = Logger::INFO

set_error_pages(404, "404.html")
set_error_pages(503, "503.html")


