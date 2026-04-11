require "webmock/rspec"

# Disable all real HTTP connections in tests. Any unexpected external call
# will raise WebMock::NetConnectNotAllowedError, making network leaks visible.
WebMock.disable_net_connect!(allow_localhost: true)
