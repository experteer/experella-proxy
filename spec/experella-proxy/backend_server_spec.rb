require 'spec_helper'

describe ExperellaProxy::BackendServer do

  let(:backend) {
    ExperellaProxy::BackendServer.new("host", "port", {:concurrency => "2", :name => "name",
                                                       :accepts => {"Host" => "experella", :path => "ella"},
                                                       :mangle => {"Connection" => "close"}
                                                      })
  }
  let(:min_backend) {
    ExperellaProxy::BackendServer.new("host", "port")
  }
  let(:matcher) {
    backend.message_matcher
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

    it "has a message matcher" do
      backend.message_matcher.should_not be_nil
      min_backend.message_matcher.should_not be_nil
    end

    it "mangle should be nil" do
      backend.mangle.should == {:Connection => "close"}
      min_backend.mangle.should be_nil
    end

    it "has workload zero" do
      backend.workload.should eql 0
    end
  end

  shared_examples "the message matcher" do

    it "returns a proc" do
      matcher.should be_an_instance_of Proc
    end

  end

  describe "#accept?" do


    it "returns false if desired request header missing" do
      request = ExperellaProxy::Request.new("")
      request.update_header(:request_url => "/docs")
      backend.accept?(request).should be_false
    end


    it "returns false if request headers doesn't match the message_matcher" do
      request = ExperellaProxy::Request.new("")
      request.update_header(:Host => "experella.com", :request_url => "/docs")
      backend.accept?(request).should be_false
      request.uri.update(:path => "godzilla")
      backend.accept?(request).should be_false
    end

    it "accepts a block as message matcher" do
      lambdaBackend = ExperellaProxy::BackendServer.new("host", "port", {:concurrency => "2", :name => "name",
                                                         :accepts => lambda { |req|
                                                           if req.header[:Host] == "google.com"
                                                             true
                                                           else
                                                             false
                                                           end
                                                         }
      })
      request = ExperellaProxy::Request.new("")
      request.update_header(:Host => "google.com", :request_url => "/docs")
      lambdaBackend.accept?(request).should be_true
      request.update_header(:Host => "experella.com", :request_url => "/docs")
      lambdaBackend.accept?(request).should be_false
    end

    it "returns true if full message_matcher finds matches in request headers" do
      request = ExperellaProxy::Request.new("")
      request.update_header(:Host => "experella.com")
      request.uri.update(:path => "experella")
      backend.accept?(request).should be_true
    end

  end

end