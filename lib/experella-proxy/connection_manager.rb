module ExperellaProxy
  # static getter for the connection_manager variable
  #
  # @return [ConnectionManager] connection_manager
  def self.connection_manager
    @connection_manager
  end

  # The ConnectionManager is responsible for queueing and matching frontend {Connection} and {BackendServer} objects
  class ConnectionManager
    # The constructor
    #
    def initialize
      @connection_queue = [] # array queue of client connection objects
      @backend_queue = [] # array queue of available backend servers
      @backend_list = {} # list of all backend servers
    end

    # Matches {Request} to queued {BackendServer}
    #
    # Removes first matching {BackendServer} from queue and returns it.
    # It will requeue the {BackendServer} instantly,
    # if {BackendServer#workload} is smaller than {BackendServer#concurrency}
    #
    # Queues {Request#conn} if no available {BackendServer} matches
    #
    # Returns false if no registered {BackendServer} matches
    #
    # @return [BackendServer] first matching BackendServer from the queue
    # @return [Symbol] :queued if Connection was queued
    # @return [Boolean] false if no registered Backend matches the Request
    def backend_available?(request)
      @backend_queue.each do |backend|
        if backend.accept?(request)
          # connect backend to requests connection if request matches
          backend.workload += 1
          ret = @backend_queue.delete(backend)
          # requeue backend if concurrency isnt maxed
          @backend_queue.push(backend) if backend.workload < backend.concurrency
          return ret
        end
      end
      if match_any_backend?(request)
        # push requests connection on queue if no backend was connected
        @connection_queue.push(request.conn)
        :queued
      else
        false
      end
    end

    # Called by a {Connection} when the {BackendServer} is done.
    #
    # Connects backend to a matching queued {Connection} or pushes server back on queue
    #
    # @param backend [BackendServer] BackendServer which got free
    # @return [NilClass]
    def free_backend(backend)
      # check if any queued connections match new available backend
      conn = match_connections(backend)
      if conn
        # return matching connection
        # you should try to connect the new backend to this connection
        return conn
      else
        # push free backend on queue if it wasn't used for a queued conn or is already queued (concurrency)
        @backend_queue.push(backend) if @backend_list.include?(backend.name) && !@backend_queue.include?(backend)
        backend.workload -= 1
      end
      nil
    end

    # Adds a new {BackendServer} to the list and queues or connects it
    #
    # @param backend [BackendServer] a new BackendServer
    # @return [Connection] a queued connection that would match the BackendServer
    # @return [Boolean] true if backend was added to list
    def add_backend(backend)
      @backend_list[backend.name] = backend

      # check if any queued connections match new available backend
      conn = match_connections(backend)
      if conn
        # return matching connection
        # you should try to connect the new backend to this connection
        return conn
      else
        # queue new backend
        @backend_queue.push(backend)
      end
      true
    end

    # Removes a {BackendServer} from list and queue
    #
    # @param backend [BackendServer] the BackendServer to be removed
    # @return [Boolean] true if a backend was removed, else returns false
    def remove_backend(backend)
      ret = @backend_list.delete(backend.name)
      @backend_queue.delete(backend)

      if ret
        true
      else
        false
      end
    end

    # Removes a connection from the connection_queue
    #
    # @param conn [Connection] Connection to be removed
    def free_connection(conn)
      @connection_queue.delete(conn)
    end

    # returns the count of the currently queued {BackendServer}s
    #
    # @return [int]
    def backend_queue_count
      @backend_queue.size
    end

    # returns the count of the registered{BackendServer}s
    #
    # @return [int]
    def backend_count
      @backend_list.size
    end

    # returns the count of the currently queued connections
    #
    # @return [int]
    def connection_count
      @connection_queue.size
    end

  private

    # Matches request to all known backends
    #
    # @return [Boolean] true if it can be matched, false if request is not accepted at all
    def match_any_backend?(request)
      @backend_list.each_value do |v|
        return true if v.accept?(request)
      end
      false
    end

    # Matches queued connections with a backend
    #
    # @return [Connection] matching connection
    # @return [NilClass] nothing matched
    def match_connections(backend)
      @connection_queue.each do |conn|
        if backend.accept?(conn.get_request)
          return conn
        end
      end
      nil
    end
  end
end
