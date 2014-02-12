require 'spec_helper'

describe ExperellaProxy::BackendServer do

  let(:backend) {
    ExperellaProxy::BackendServer.new("host", "port", {:concurrency => "2", :name => "name",
                                                       :accepts => {"Host" => "experella"},
                                                       :mangle => {"Connection" => "close"}
                                                      })
  }
  let(:min_backend) {
    ExperellaProxy::BackendServer.new("host", "port")
  }
  let(:pattern) {
    backend.message_pattern
  }

  describe "#new" do

    it "returns a ExperellaProxy::BackendServer" do
      backend.should be_an_instance_of ExperellaProxy::BackendServer
    end

    it "has a host" do
      backend.host.should eql "host"
    end

    it "has a port" do
      backend.port.should eql "port"
    end

    it "has a name" do
      backend.name.should eql "name"
      min_backend.name.should eql "host:port"
    end

    it "has a concurrency" do
      backend.concurrency.should eql 2
      min_backend.concurrency.should eql 1
    end

    it "has a message pattern" do
      backend.message_pattern.should_not be_nil
      min_backend.message_pattern.should_not be_nil
    end

    it "mangle should be nil" do
      backend.mangle.should == {:Connection => "close"}
      min_backend.mangle.should be_nil
    end

    it "has workload zero" do
      backend.workload.should eql 0
    end
  end

  shared_examples "the message pattern" do

    it "returns a proc" do
      pattern.should be_an_instance_of Proc
    end

  end


  describe "#update_message_pattern" do

    #it "adds the hash parameter to the message_pattern and overwrites values of duplicate keys" do
    #  backend.update_message_pattern({"Host" => "experella.de", "Connection" => "keep-alive"})
    #  pattern = backend.message_pattern
    #  pattern[:Host].should eql Regexp.new("experella.de")
    #  pattern[:Connection].should eql Regexp.new("keep-alive")
    #end

    it_should_behave_like "the message pattern"
  end

  describe "#accept?" do


    it "returns false if request header doesn't have all keys of message_pattern" do
      request = ExperellaProxy::Request.new("")
      request.update_header(:request_url => "/docs")
      backend.accept?(request).should be_false
    end

    it "returns false if request headers don't match full message_pattern" do
      request = ExperellaProxy::Request.new("")
      request.update_header(:Host => "google.com", :request_url => "/docs")
      backend.accept?(request).should be_false
    end

    it "returns true if full message pattern finds matches in request headers" do
      request = ExperellaProxy::Request.new("")
      request.update_header(:Host => "experella.com", :request_url => "/docs")
      backend.accept?(request).should be_true
    end

  end

end