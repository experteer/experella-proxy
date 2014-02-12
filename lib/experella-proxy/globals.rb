module ExperellaProxy

  # defined hop by hop header fields
  HOP_HEADERS = ["Connection", "Keep-Alive", "Proxy-Authorization", "TE", "Trailer", "Transfer-Encoding", "Upgrade"]

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

    # Get the global logger
    #
    # @return [Logger] logger set in config object
    def log
      ExperellaProxy.config.logger
    end

    # Get the global connection manager
    #
    # @return [ConnectionManager] connection_manager object
    def connection_manager
      ExperellaProxy.connection_manager
    end

  end
end