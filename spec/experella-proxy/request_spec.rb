require 'spec_helper'

describe ExperellaProxy::Request do

  let(:request) do
    ExperellaProxy::Request.new("conn")
  end

  describe "#new" do

    it "initializes connection variable and reader" do
      request.conn.should eql("conn")
    end

    it "initializes header hash and reader" do
      request.header.should be_an_instance_of Hash
    end

    it "initializes uri hash and reader" do
      request.uri.should be_an_instance_of Hash
    end

    it "initializes keep_alive boolean and reader" do
      request.keep_alive.should be_true
      request.keep_alive = false
      request.keep_alive.should be_false
    end

    it "initializes chunked boolean and reader" do
      request.chunked.should be_false
      request.chunked = true
      request.chunked.should be_true
    end
  end

  describe "#<<" do
    it "adds data to send_buffer" do
      request << "hel"
      request << "lo"
      request.flush.should eql("hello")
    end
  end

  describe "#flush" do
    it "returns and clears the send_buffer" do
      request << "hello"
      request.flush.should eql("hello")
      request.flushed?.should == true
    end
  end

  describe "#add_uri" do
    it "adds a hash to the URI hash" do
      request.add_uri(:path => "/hello")
      request.uri[:path].should eql("/hello")
    end
  end

  describe "#update_header" do
    it "updates the header hash and symbolizes input keys" do
      request.update_header("Host" => "xyz", :request_url => "abcd")
      request.header[:Host].should eql("xyz")
      request.header[:request_url].should eql("abcd")
      request.header["Host"].should be_nil
    end

    it "overwrites values of existing keys" do
      request.update_header("Host" => "xyz", :request_url => "abcd")
      request.update_header("Host" => "abc")
      request.header.should eql(:Host => "abc", :request_url => "abcd")
    end
  end

  describe "#reconstruct_header" do
    it "writes a valid http header into send_buffer" do
      request << "HeaderDummy\r\n\r\n"
      request.update_header(:http_method => "GET", :request_url => "/index",
                            "Host" => "localhost", "Connection" => "keep-alive", :"Via-X" => %w(Lukas Amy George))
      request.reconstruct_header
      data = request.flush
      data.start_with?("GET /index HTTP/1.1\r\n").should be_true
      data.should include("Connection: keep-alive\r\n")
      data.should include("Via-X: Lukas\r\n")
      data.should include("Via-X: Amy\r\n")
      data.should include("Via-X: George\r\n")
      data.end_with?("\r\n\r\n").should be_true
    end

    it "keeps folded/unfolded headers as is" do
      request.update_header(:http_method => "GET", :request_url => "/index", "Host" => "localhost",
                            "Connection" => "keep-alive", "Via" => "1.1 experella1, 1.1 experella2, 1.1 experella3",
                             :"Via-X" => %w(Lukas Amy George))
      request.reconstruct_header
      data = request.flush
      data.should include("1.1 experella1, 1.1 experella2, 1.1 experella3\r\n")
      data.end_with?("\r\n\r\n").should be_true
      data.should include("Via-X: Lukas\r\n")
      data.should include("Via-X: Amy\r\n")
      data.should include("Via-X: George\r\n")
      data.end_with?("\r\n\r\n").should be_true
    end
  end

end
