require 'sinatra/base'

# Simple Hello World! Testserver
#
class HelloWorldServer < Sinatra::Base

  get '/' do

    "Hello World!"

  end


# start the server if ruby file executed directly
  run! if app_file == $0

end
