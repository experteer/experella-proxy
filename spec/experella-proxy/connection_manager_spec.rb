require 'spec_helper'

describe ExperellaProxy::ConnectionManager do

  let(:manager) {
    ExperellaProxy::ConnectionManager.new
  }

  class Testconnection

    def initialize()
      @request = ExperellaProxy::Request.new(self)
    end

    def get_request
      @request
    end
  end

  describe "#backend_count" do
    it "returns size of the backend_list" do
      manager.backend_count.should == 0
    end
  end

  describe "#backend_queue_count" do
    it "returns size of the backend_queue" do
      manager.backend_queue_count.should == 0
    end
  end

  describe "#add_backend" do
    it "should add a BackendServer to list and queue and return true" do
      ret = manager.add_backend(ExperellaProxy::BackendServer.new("host", "port"))
      manager.backend_count.should == 1
      manager.backend_queue_count.should == 1
      ret.should == true
    end

    it "should add a BackendServer to list and return conn if a queued conn matches" do
      manager.add_backend(ExperellaProxy::BackendServer.new("host", "port"))
      manager.backend_count.should == 1
      manager.backend_queue_count.should == 1
      manager.backend_available?(Testconnection.new().get_request)
      manager.backend_available?(Testconnection.new().get_request)
      manager.backend_count.should == 1
      manager.backend_queue_count.should == 0
      manager.connection_count.should == 1
      ret = manager.add_backend(ExperellaProxy::BackendServer.new("hostx", "port"))
      manager.backend_count.should == 2
      manager.backend_queue_count.should == 0
      ret.should be_an_instance_of Testconnection
    end

  end

  describe "#remove_backend" do
    it "should return true if a backend was removed" do
      backend = ExperellaProxy::BackendServer.new("host", "port")
      manager.add_backend(backend)
      manager.backend_count.should == 1
      manager.backend_queue_count.should == 1
      ret = manager.remove_backend(backend)
      ret.should be_true
      manager.backend_count.should == 0
      manager.backend_queue_count.should == 0
    end

    it "should return false if no backend was removed" do
      backend = ExperellaProxy::BackendServer.new("host", "port")
      manager.remove_backend(backend).should be_false
    end
  end

  describe "#free_backend" do
    it "should return a connection if any queued conn matches" do
      backend = ExperellaProxy::BackendServer.new("host", "port")
      manager.add_backend(backend)
      manager.backend_available?(Testconnection.new().get_request)
      manager.backend_available?(Testconnection.new().get_request)
      ret = manager.free_backend(backend)
      ret.should be_an_instance_of Testconnection
    end

    it "should return nil and requeue backend if no conn matches" do
      backend = ExperellaProxy::BackendServer.new("host", "port")
      manager.add_backend(backend)
      manager.backend_available?(Testconnection.new().get_request)
      backend_queue = manager.backend_queue_count
      workload = backend.workload
      ret = manager.free_backend(backend)
      ret.should == nil
      manager.backend_queue_count.should == (backend_queue + 1)
      backend.workload.should == (workload - 1)
    end

  end

  describe "#free_connection" do
    it "should remove connection from queue" do
      backend = ExperellaProxy::BackendServer.new("host", "port")
      manager.add_backend(backend)
      connections = []
      connections[1] = Testconnection.new()
      connections[2] = Testconnection.new()
      manager.backend_available?(connections[1].get_request)
      manager.backend_available?(connections[2].get_request)
      count_before = manager.connection_count
      manager.free_connection(connections[2])
      manager.connection_count.should == (count_before - 1)
    end
  end

  describe "#backend_available?" do
    before(:each) do
      manager.add_backend(ExperellaProxy::BackendServer.new("host", "port", {:concurrency => 3, :accepts => {"Host" => "test"}}))
      manager.add_backend(ExperellaProxy::BackendServer.new("host2", "port", {:accepts => {"Host" => "bla"}}))
      manager.add_backend(ExperellaProxy::BackendServer.new("host3", "port", {:accepts => {"Host" => "blax"}}))
    end
    it "returns first matching backend and removes it from queue" do
      conn = Testconnection.new
      conn.get_request.update_header("Host" => "loremblaxipsum")
      before_count = manager.backend_queue_count
      ret = manager.backend_available?(conn.get_request)
      ret.name.should == "host2:port"
      manager.backend_queue_count.should == (before_count - 1)
    end

    it "should requeue matching backend if concurrency is smaller than workload" do
      conn = Testconnection.new
      conn.get_request.update_header("Host" => "loremtestipsum")
      before_count = manager.backend_queue_count
      ret = manager.backend_available?(conn.get_request)
      ret.name.should == "host:port"
      manager.backend_queue_count.should == before_count
    end

    it "returns :queued if no matching backend is currently available" do
      conn = Testconnection.new
      conn.get_request.update_header("Host" => "loremblaipsum")
      manager.backend_available?(conn.get_request)
      before_count = manager.backend_queue_count
      ret = manager.backend_available?(conn.get_request)
      ret.should == :queued
      manager.backend_queue_count.should == before_count
    end

    it "returns false if no registered backend matches" do
      conn = Testconnection.new
      conn.get_request.update_header("Host" => "loremipsum")
      before_count = manager.backend_queue_count
      ret = manager.backend_available?(conn.get_request)
      ret.should be_false
      manager.backend_queue_count.should == before_count
    end

  end

end