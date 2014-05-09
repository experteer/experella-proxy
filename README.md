#Experella-Proxy

[![Gem Version](https://badge.fury.io/rb/experella-proxy.png)](http://badge.fury.io/rb/experella-proxy)
[![Build Status](https://travis-ci.org/experteer/experella-proxy.svg?branch=master)](https://travis-ci.org/experteer/experella-proxy)

A balancing EventMachine reverse proxy based on [em-proxy](https://github.com/igrigorik/em-proxy). 
See our [presentation](http://experteer.github.io/experella-proxy/index.html) for a more detailed overview.

Configurable in pure ruby!

Supports:

+ Persistent connections and HTTP Pipelining for clients
+ Response streaming
+ Post Request data streaming
+ Request header routing logic completely configurable for each server
+ Request header manipulation completely configurable for each server
+ Daemonized control using ruby [Daemons](http://daemons.rubyforge.org/)
+ TLS support and a default self-signed ssl certification

Proxy uses [http_parser](https://github.com/tmm1/http_parser.rb) to parse http data and is thereby subject to the parsers restrictions

The proxy is build for low proxy to server latency and does not support persistent connections to servers. Keep that in mind
as it can severely influence proxy performance overhead.

It balances for every single http-request and not per client/connection.

##Install as Gem

To use experella-proxy simply install it as a gem.

```
gem install experella-proxy
```

##How to start

Experella-Proxy is controlled by ruby Daemons default commands (run, start, restart, stop) and provides
a template config initialization command (init destination).

run, start and restart require an absolute config file path.

To initialize the proxy with default config files init the proxy to a directory of your choice.

For example

```
$> experella-proxy init ~
```

will initialize default config to $HOME/proxy


Then simply use:

```
$> experella-proxy start -- --config=~/proxy/config.rb
$> experella-proxy restart -- --config=~/proxy/config.rb
$> experella-proxy stop
```
to control the proxy with the default config file.


### BASE_PORT option for default config

To set other base port you have to prefix the previous commands with BASE_PORT=xxxx e.g.

Running ports below 1024 probably requires "rvmsudo" to run properly

```
$> BASE_PORT=3000 experella-proxy start -- --config=~/proxy/config.rb
```

##Config file

You need to provide a valid config file for the proxy to run.

Config files use a ruby DSL with the following options

###Backend Server

Each server is configured independent of other servers, so each desired routing dependency has to be added manually.
i.e. if you want to route an inimitable request to an unique backend, you have to exclude that match in all other servers.


```
backend         Takes an options hash defining a backend_server
  required keys =>   :host   Host address of the Server, can be IP or domain, String
                     :port   Port of the Server, Integervalue as String

  optional keys =>   :name   Name of the Server used in the Logger and Cashing, String
                             Will default to #{host}:#{port} but needs to be unique, though theoretical 
                             there can be multiple servers with the same host:port value pair!

                     :concurrency max Number of concurrent connections, Integervalue as String, Default is 1

                     :accepts     Hash containing keys matching HTTP headers or URI :path, :port, :query
                                  Values are Regexp as Strings or as Regex, use ^((?!pattern).)*$ to negate matching
                                  Care: Will match any Header/value pairs not defined in the accepts Hash
                                  Optionally you can provide a lambda with your own routing logic

                     :mangle      Hash containing keys matching HTTP headers. Values can be callable block or Strings
                                  Mangle modifies the header value based on the given block
                                  or replaces the header value with the String
```

####Example

```ruby
    backend(:name => "Srv1", :host => "192.168.0.10", :port => "80", :concurrency => "1",
     :accepts => {"request_url" => "^((?!/(#{not-for-srv1})($|/)).)*$"},
     :mangle => {"Host" => lambda{ |host|
                           if host.match(/localhost/)
                              'www.host-i-need.com'
                           else
                              host
                           end
                           }
              }
    )
```
###Logging

You can set a logger but the proxy will just log some startup messages. See set_on_event how to see more.

```
set_logger      specifies the Logger used by the program.
				The Logger must support debug/info/warn/error/fatal functions
```

###Events

As a lot of things are happening in the proxy the appropriate level of logging is hard to find. So the proxy just emits some events. You can receive these events and do whatever you like to do (log, mail,....) by defining the event handler with:

```
set_on_event     specifies the event handler to be used. The handler is a lambda or Proc
				 accepting a Symbol (name of the event) and a hash of details.
```

###Proxy Server

```
set_proxy       Add proxy as Hash with :host => "string-ip/domain", :port => Fixnum, :options => Hash
                The proxy will listen on every host:port hash added with this function.
                :options can activate :tls with given file paths to :private_key_file and :cert_chain_file
                file paths are relative to the config file directory
```
####Example

```ruby
    set_proxy(:host => "127.0.0.1", :port => 8080)
    set_proxy(:host => "127.0.0.1", :port => 443,
              :options => {:tls => true,
                           :private_key_file => 'ssl/private/experella_proxy.key',
                           :cert_chain_file => 'ssl/certs/experella_proxy.pem'})
    set_proxy(:host => "127.0.0.2", :port => 8080)
    set_proxy(:host => "192.168.100.168", :port => 6666)
```

###Connection timeout

```
set_timeout     Time as float when an idle persistent connection gets closed (no receive/send events occured)
```

###Error pages

```
set_error_pages Add html error-pages to the proxy, requires 2 arguments
                1st arg: the error code as Fixnum
                2nd arg: path to an error page html file relative to the config file directory
                Currently 404 and 503 error codes are supported
```

####Example

```ruby
    set_error_pages(404, "404.html")
    set_error_pages(503, "503.html")
```


## Modify connection logic and data streams

Override server's run function

```ruby
    def run

      Proxy.start(options = {}) do |conn|

        log.info msec + "new Connection @" + signature.to_s

        # called on successful backend connection
        conn.on_connect do |backend|

        end

        # modify / process request stream
        # and return modified data
        conn.on_data do |data|
          data
        end

        # modify / process response stream+
        # and return modified response
        conn.on_response do |backend, resp|
          resp
        end

        # termination logic
        conn.on_finish do |backend|

        end

        # called if client finishes connection
        conn.on_unbind do

        end
      end

    end
```

## Development

In the dev folder a development binary is provided which allows execution without installation as gem.

The test folder provides simple sinatra servers for testing/debugging which can be run with rake tasks.

Additionally you can activate simplecov code coverage analysis for specs by setting COVERAGE=true

```
$> COVERAGE=true rake spec
```

## Additional Information

+ [em-proxy](https://github.com/igrigorik/em-proxy)
+ [http_parser](https://github.com/tmm1/http_parser.rb)
+ [Eventmachine](https://github.com/eventmachine/eventmachine)
+ [Daemons](http://daemons.rubyforge.org/)
+ [What proxies must do](http://www.mnot.net/blog/2011/07/11/what_proxies_must_do)


## License

MIT License - Copyright (c) 2014 Dennis-Florian Herr @Experteer GmbH
