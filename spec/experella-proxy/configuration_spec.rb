require 'spec_helper'

describe ExperellaProxy::Configuration do
  let(:config) do
    ExperellaProxy.config
  end

  it "should load a config file" do
    config.backends.size.should == 4
    config.timeout.should == 6.0
    config.proxy.size.should == 2
  end

  it "should load error pages" do
    config.error_pages[404].empty?.should be_false
    config.error_pages[503].empty?.should be_false
  end

  it "should raise NoConfigError if config filepath doesn't exist" do
    lambda do config.read_config_file("/a/non/existing/filepath")
    end.should raise_error(ExperellaProxy::Configuration::NoConfigError)
  end
end
