module ExperellaProxy
  # ExperellaProxy Gemversion
  # 0.0.8
  # * fixed a parsing bug where no data was send when backend used connection close to indicate message end
  # 0.0.7
  # * fixed minor issues with ruby 2.0
  # * fixed a typo in default config
  # * refactored mangling in own method
  # * refactored message pattern and matching
  # 0.0.6
  # * updated homepage
  # 0.0.5
  # * added :host_port option to backend configuration
  # 0.0.4
  # * added lambda for accept filtering
  #
  # 0.0.3
  # * added self-signed SSL certificate for TLS/HTTPS
  # * added config template init functionality
  #
  VERSION = "0.0.8"
end
