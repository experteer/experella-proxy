require 'spec_helper'

# Dirty integration tests for the proxy connection logic
#
# uses the simple echo server in spec/echo-server/echo_server.rb and the test_config.rb
#
# Proxy logfile in spec/log/spec.log
#
describe ExperellaProxy do
  include POSIX::Spawn
  include ExperellaProxy::Globals
  let(:echo_server) {
    File.expand_path("../../echo-server/echo_server.rb", __FILE__)
  }
  let(:experella_proxy) {
    File.expand_path("../../../bin/experella-proxy", __FILE__)
  }

  # static testnames send to spawned experella for simplecov
  ENV_TESTNAMES = {
    "should get response from the echoserver via the proxy" => "response",
    "should respond with 404" => "404",
    "should respond with 400 on malformed request" => "400",
    "should respond with 503" => "503",
    "should reuse keep-alive connections" => "keep-alive",
    "should handle chunked post requests and strip invalid Content-Length" => "chunked-request",
    "should rechunk and stream Transfer-Encoding chunked responses" => "chunked-response",
    "should timeout inactive connections after config.timeout" => "timeout",
    "should handle pipelined requests correctly" => "pipelined",
    "should accept requests on all set proxy domains" => "multiproxy",
    "should be able to handle post requests" => "post"
  }

  describe "EchoServer" do
    before :each do
      @pid = spawn("ruby", "#{echo_server}", "127.0.0.10", "7654")
      sleep(0.8) #let the server startup, specs may fail if this is set to low
    end
    after :each do
      Process.kill('QUIT', @pid)
      sleep(1.0) # give the kill command some time
    end

    it "should get response from the echoserver" do
      lambda {
        EM.run do
          http = EventMachine::HttpRequest.new("http://127.0.0.10:7654").get({:connect_timeout => 1})
          http.errback {
            EventMachine.stop
            raise "http request failed"
          }
          http.callback {
            http.response.should start_with "you sent: "
            EventMachine.stop
          }
        end
      }.should_not raise_error
    end
  end

  describe "Proxy" do
    before :each do |test|
      if ENV["COVERAGE"]
        ENV["TESTNAME"] = ENV_TESTNAMES[test.example.description]
      end
      @pid = spawn("ruby", "#{echo_server}", "127.0.0.10", "7654")
      @pid2 = spawn("#{experella_proxy}", "run", "--", "--config=#{File.join(File.dirname(__FILE__),"/../fixtures/test_config.rb")}")
      sleep(0.8) #let the server startup, specs may fail if this is set to low
      ExperellaProxy.init(:configfile => File.join(File.dirname(__FILE__),"/../fixtures/test_config.rb"))
      config.backends.each do |backend|
        connection_manager.add_backend(ExperellaProxy::BackendServer.new(backend[:host], backend[:port], backend))
      end
    end
    after :each do
      log.close
      Process.kill('QUIT', @pid)
      Process.kill('TERM', @pid2)
      sleep(1.0) # give the kill command some time
    end

    it "should get response from the echoserver via the proxy" do
      log.info "should get response from the echoserver via the proxy"
      EM.epoll
      EM.run do
        lambda {
          EventMachine.add_timer(0.2) do
            http = EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}"
            ).get({:connect_timeout => 1, :head => {"Host" => "experella.com"}})
            http.errback {
              EventMachine.stop
              raise "http request failed"
            }
            http.callback {
              http.response.should start_with "you sent: "
              EventMachine.stop
            }
          end
        }.should_not raise_error
      end
    end

    it "should respond with 404" do
      log.info "should respond with 404"
      EM.epoll
      EM.run do
        lambda {
          EventMachine.add_timer(0.2) do

            multi = EventMachine::MultiRequest.new
            multi_shuffle = []
            multi_shuffle[0] = Proc.new {
              multi.add :head, EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}"
              ).head({:connect_timeout => 1})
            }
            multi_shuffle[1] = Proc.new {
              multi.add :get, EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}"
              ).get({:connect_timeout => 1})
            }
            multi_shuffle.shuffle!
            multi_shuffle.each do |p|
              p.call
            end

            multi.callback do
              unless multi.responses[:errback].empty?
                EventMachine.stop
                raise "http request failed"
              end
              multi.responses[:callback][:head].response.empty?.should be_true
              multi.responses[:callback][:head].response_header.status.should == 404
              multi.responses[:callback][:get].response_header.status.should == 404
              multi.responses[:callback][:get].response.should start_with "<!DOCTYPE html>"
              EventMachine.stop
            end


          end
        }.should_not raise_error
      end
    end

    it "should respond with 400 on malformed request" do
      log.info "should respond with 400 on malformed request"
      EM.epoll
      EM.run do
        lambda {
          EventMachine.add_timer(0.2) do
            http = EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}"
            ).post({:connect_timeout => 1, :head => {"Host" => "experella.com", "Transfer-Encoding" => "chunked"},
                   :body => "9\r\nMalformed\r\na\r\nchunked da\r\n2\rta HERE\r\n0\r\n\r\n"})
            http.errback {
              EventMachine.stop
              raise "http request failed"
            }
            http.callback {
              http.response_header.status.should == 400
              EventMachine.stop
            }
          end
        }.should_not raise_error
      end
    end

    it "should respond with 503" do
      log.info "should respond with 503"
      EM.epoll
      EM.run do
        lambda {
          EventMachine.add_timer(0.2) do

            multi = EventMachine::MultiRequest.new
            multi_shuffle = []
            multi_shuffle[0] = Proc.new {
              multi.add :head, EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}/oneroute"
              ).head({:connect_timeout => 1, :head => {"Host" => "experella.com"}})
            }
            multi_shuffle[1] = Proc.new {
              multi.add :get, EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}/anotherpath"
              ).get({:connect_timeout => 1, :head => {"Host" => "experella.com"}})
            }
            multi_shuffle.shuffle!
            multi_shuffle.each do |p|
              p.call
            end

            multi.callback do
              unless multi.responses[:errback].empty?
                EventMachine.stop
                raise "http request failed"
              end
              multi.responses[:callback][:head].response.empty?.should be_true
              multi.responses[:callback][:head].response_header.status.should == 503
              multi.responses[:callback][:get].response_header.status.should == 503
              multi.responses[:callback][:get].response.should start_with "<!DOCTYPE html>"
              EventMachine.stop
            end


          end
        }.should_not raise_error
      end
    end

    it "should reuse keep-alive connections" do
      log.info "should reuse keep-alive connections"
      EM.epoll
      EM.run do
        lambda {
          EventMachine.add_timer(0.2) do
            conn = EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}")
            req1 = conn.get({:connect_timeout => 1, :keepalive => true, :head => {"Host" => "experella.com"}})

            req1.errback {
              EventMachine.stop
              raise "http request 1 failed"
            }
            req1.callback {
              req1.response.should start_with "you sent: "
              req2 = conn.get({:path => '/about/', :connect_timeout => 1, :keepalive => true, :head => {"Host" => "experella.com"}})
              req2.errback {
                EventMachine.stop
                raise "http request 2 failed"
              }
              req2.callback {
                req2.response.should start_with "you sent: "
                req3 = conn.get({:connect_timeout => 1, :head => {"Host" => "experella.com"}})
                req3.errback {
                  EventMachine.stop
                  raise "http request 3 failed"
                }
                req3.callback {
                  req3.response.should start_with "you sent: "
                  EventMachine.stop
                }
              }
            }
          end
        }.should_not raise_error
      end
    end

    it "should handle chunked post requests and strip invalid Content-Length" do
      log.info "should stream chunked post requests"
      EM.epoll
      EM.run do
        lambda {
          EventMachine.add_timer(0.2) do
            # this will issue a Post Request with Content-Length AND Transfer-Encoding chunked, where the data is
            # correctly encoded in chunks. The Proxy should therefor strip the Content-Length and forward the data
            # in chunks.
            expected_headers = []
            expected_headers << "POST / HTTP/1.1"
            expected_headers << "Host: experella.com"
            expected_headers << "Connection: close"
            expected_headers << "Via: 1.1 experella"
            expected_headers << "User-Agent: EventMachine HttpClient"
            expected_headers << "Transfer-Encoding: chunked"

            # generate random chunked message
            body = String.new
            expected_body = String.new
            chunks = 20 + rand(20)
            # all alphanumeric characters
            o = [('a'..'z'), ('A'..'Z'), ('0'..'9')].map { |i| i.to_a }.flatten
            while chunks > 0 do
              #chunksize 10 to 1510 characters
              string = (0...(10 + rand(1500))).map { o[rand(o.length)] }.join
              body << string.size.to_s(16)
              body << "\r\n"
              body << string
              expected_body << string
              body << "\r\n"
              chunks -= 1
            end
            body << "0\r\n\r\n"

            http = EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}"
            ).post({:connect_timeout => 1, :head => {"Host" => "experella.com", "Transfer-Encoding" => "chunked"},
                   :body => body})
            http.errback {
              EventMachine.stop
              raise "http request failed"
            }
            http.callback {
              # as the proxy can rechunk large data in different chunks, it's required to remove all chunk encoding
              # characters and compare it to the unchunked random data saved in expected_body

              # split header and body
              response = http.response.partition("\\r\\n\\r\\n")
              # split by chunked encoding delimiter
              response[2] = response[2].split("\\r\\n").map { |i|
                # delete all strings containing the hex-size information (FFF = length 3 = 4500 chars)
                if i.length <= 3
                  i = ""
                else
                  i = i
                end
              }.join
              response = response.join
              expected_headers.each do |header|
                response.should include header
              end
              response.should include expected_body

              EventMachine.stop
            }
          end
        }.should_not raise_error
      end

    end

    # check echo_server for the response
    it "should rechunk and stream Transfer-Encoding chunked responses" do
      log.info "should rechunk and stream Transfer-Encoding chunked responses"
      EM.epoll
      EM.run do
        lambda {
          EventMachine.add_timer(0.2) do
            http = EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}/chunked"
            ).get({:connect_timeout => 1, :head => {"Host" => "experella.com"}})
            http.errback {
              EventMachine.stop
              raise "http request failed"
            }
            received_chunks = ""
            http.stream { |chunk|
             received_chunks << chunk
            }
            http.callback {
              true.should be_true
              received_chunks.should == "chunk one chunk two chunk three chunk four chunk 123456789abcdef"
              http.response_header["Transfer-Encoding"].should == "chunked"
              EventMachine.stop
            }
          end
        }.should_not raise_error
      end

    end

    it "should timeout inactive connections after config.timeout" do
      log.info "should timeout inactive connections after config.timeout"
      EM.epoll
      EM.run do

        lambda {
          EventMachine.add_timer(0.2) do
            time = Time.now
            conn = EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}")
            req1 = conn.get({:connect_timeout => 1, :inactivity_timeout => config.timeout + 5,
                             :keepalive => true, :head => {"Host" => "experella.com"}})
            req1.errback {
              #this shouldnt happen, but when it does it should at least be because of a timeout
              time = Time.now - time
              time.should >= config.timeout
              time.should < config.timeout + 5
              EventMachine.stop
              raise "http request failed"
            }
            req1.callback {
              req1.response.should start_with "you sent: "
            }
            #check for inactivity timeout
            EventMachine.add_periodic_timer(1) do
              if conn.conn.get_idle_time.nil?
                time = Time.now - time
                time.should >= config.timeout
                time.should <= config.timeout + 5
                EventMachine.stop
              elsif Time.now - time > config.timeout + 6
                EventMachine.stop
                raise "Timeout failed completly"
              end
            end
          end
        }.should_not raise_error
      end
    end


    it "should handle pipelined requests correctly" do
      log.info "should handle pipelined requests correctly"
      EM.epoll
      EM.run do
        lambda {
          EventMachine.add_timer(0.2) do
            conn = EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}")

            pipe1 = conn.get({:connect_timeout => 1, :keepalive => true, :head => {"Host" => "experella.com"}})
            pipe2 = conn.get({:path => '/about/', :connect_timeout => 1, :keepalive => true, :head => {"Host" => "experella.com"}})
            pipe3 = conn.get({:connect_timeout => 1, :head => {"Host" => "experella.com"}})
            pipe1.errback {
              EventMachine.stop
              raise "http request 1 failed"
            }
            pipe1.callback {
              pipe1.response.should start_with "you sent: "
              pipe2.finished?.should be_false
              pipe3.finished?.should be_false
            }
            pipe2.errback {
              EventMachine.stop
              raise "http request 2 failed"
            }
            pipe2.callback {
              pipe2.response.should start_with "you sent: "
              pipe1.finished?.should be_true
              pipe3.finished?.should be_false
            }
            pipe3.errback {
              EventMachine.stop
              raise "http request 3 failed"
            }
            pipe3.callback {
              pipe3.response.should start_with "you sent: "
              pipe1.finished?.should be_true
              pipe2.finished?.should be_true
              EventMachine.stop
            }
          end
        }.should_not raise_error
      end
    end

    it "should accept requests on all set proxy domains" do
      log.info "should accept requests on all set proxy domains"
      EM.epoll
      EM.run do
        lambda {
          EventMachine.add_timer(0.2) do

            multi = EventMachine::MultiRequest.new
            multi_shuffle = []
            i = 0
            while config.proxy.length > i do
              multi_shuffle[i] = Proc.new { |i|
                multi.add i, EventMachine::HttpRequest.new("http://#{config.proxy[i][:host]}:#{config.proxy[i][:port]}"
                ).get({:connect_timeout => 1, :head => {"Host" => "experella.com"}})
              }
              i += 1
            end
            multi_shuffle.shuffle!
            i = 0
            multi_shuffle.each do |p|
              p.call(i)
              i += 1
            end

            multi.callback do
              unless multi.responses[:errback].empty?
                EventMachine.stop
                raise "http request failed"
              end
              multi.responses[:callback].each_value do |resp|
                resp.response.should start_with "you sent: "
              end
              EventMachine.stop
            end
          end
        }.should_not raise_error
      end
    end

    it "should be able to handle post requests" do
      log.info "should be able to handle post requests"
      EM.epoll
      EM.run do
        lambda {
          EventMachine.add_timer(0.2) do
            http = EventMachine::HttpRequest.new("http://#{config.proxy[0][:host]}:#{config.proxy[0][:port]}"
            ).post({:connect_timeout => 1, :head => {"Host" => "experella.com"}, :body => "Message body"})
            http.errback {
              EventMachine.stop
              raise "http post failed"
            }
            http.callback {
              http.response.should start_with "you sent: "
              http.response.should end_with "Message body\""
              EventMachine.stop
            }
          end
        }.should_not raise_error
      end
    end

  end
end