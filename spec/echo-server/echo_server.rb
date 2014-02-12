require 'eventmachine'
require 'http_parser.rb'
module EchoServer

  def post_init
    @parser = Http::Parser.new
    @buffer = String.new

    @parser.on_headers_complete = proc do |h|
      if @parser.request_path == "/chunked"
        @chunked = true
      end
    end

    @parser.on_message_complete = proc do
      if @chunked
        answer = "HTTP/1.1 200 OK\r\nTransfer-Encoding: chunked\r\nConnection: close\r\n\r\n"
        answer << "9\r\nchunk one\r\n"
        answer << "a\r\n chunk two\r\n"
        answer << "d\r\n chunk three \r\n"
        answer << "b\r\nchunk four \r\n"
        answer << "15\r\nchunk 123456789abcdef\r\n0\r\n\r\n"
      else
        @buffer = "you sent: " + @buffer.dump
        answer = "HTTP/1.1 200 OK\r\nContent-Length: #{@buffer.length}\r\nConnection: close\r\n\r\n"
        answer << @buffer
      end
      send_data answer
      close_connection_after_writing
    end
  end

  def receive_data data
    @buffer << data
    @parser << data
  end

end

EventMachine.run do
  trap("QUIT") { EM.stop }

  if ARGV.count == 2
    EventMachine.start_server ARGV.first, ARGV.last.to_i, EchoServer
  else
    raise "invalid number of params, expected [server] [port]"
  end

end