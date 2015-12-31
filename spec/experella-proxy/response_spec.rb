require 'spec_helper'

describe ExperellaProxy::Response do

  let(:response) do
    ExperellaProxy::Response.new(ExperellaProxy::Request.new("conn"))
  end

  describe "#new" do

    it "initializes header hash and reader" do
      response.header.should be_an_instance_of Hash
    end
  end

  describe "#update_header" do
    it "updates the header hash and symbolizes input keys" do
      response.update_header("Host" => "xyz", :response_url => "abcd")
      response.header[:Host].should eql("xyz")
      response.header[:response_url].should eql("abcd")
      response.header["Host"].should be_nil
    end

    it "overwrites values of existing keys" do
      response.update_header("Host" => "xyz", :response_url => "abcd")
      response.update_header("Host" => "abc")
      response.header.should eql(:Host => "abc", :response_url => "abcd")
    end
  end

  describe "#reconstruct_header" do
    it "writes a valid http header into send_buffer" do
      response.update_header("Connection" => "keep-alive",
                             :"Via-X"     => %w(Lukas Amy George))
      response.reconstruct_header
      data = response.flush
      data.start_with?("HTTP/1.1 500 Internal Server Error\r\n").should be_true
      data.should include("Connection: keep-alive\r\n")
      data.should include("Via-X: Lukas\r\n")
      data.should include("Via-X: Amy\r\n")
      data.should include("Via-X: George\r\n")
      data.end_with?("\r\n\r\n").should be_true
    end

    it "keeps folded/unfolded headers as is" do
      response.update_header("Via" => "1.1 experella1, 1.1 experella2, 1.1 experella3",
                             :"Via-X"     => %w(Lukas Amy George))
      response.reconstruct_header
      data = response.flush
      data.should include("1.1 experella1, 1.1 experella2, 1.1 experella3\r\n")
      data.end_with?("\r\n\r\n").should be_true
      data.should include("Via-X: Lukas\r\n")
      data.should include("Via-X: Amy\r\n")
      data.should include("Via-X: George\r\n")
      data.end_with?("\r\n\r\n").should be_true
    end

    context "when status code does not exist in HTTP_STATUS_CODES" do
      it "returns Uknown Error" do
        response.instance_variable_set(:@status_code, 99)
        response.update_header("Connection" => "keep-alive",
                               :"Via-X"     => %w(Lukas Amy George))
        response.reconstruct_header
        data = response.flush
        data.start_with?("HTTP/1.1 99 \r\n").should be_true
      end
    end
  end


end
