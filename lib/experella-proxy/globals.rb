module ExperellaProxy
  # defined hop by hop header fields
  HOP_HEADERS = %w(Connection Keep-Alive Proxy-Authorization TE Trailer Transfer-Encoding Upgrade)

  # Provides getters for global variables
  #
  # All methods are private. The module needs to be included in every Class which needs it.
  module Globals
  private

    # @!visibility public

    # Get the global config
    #
    # @return [Configuration] config object
    def config
      ExperellaProxy.config
    end

    # Dispatch events to event handler
    #
    # @param [Symbol] name is the name of the event
    # @param [Hash] details contains details of the event
    # see ExperellaProxy::Configuration#on_event

    def event(name, details={})
      config.on_event.call(name, details)
    end

    # Get the global connection manager
    #
    # @return [ConnectionManager] connection_manager object
    def connection_manager
      ExperellaProxy.connection_manager
    end

    def logger
      config.logger
    end
  end
end
