# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# This configuration is loaded before any dependency and is restricted
# to this project. If another project depends on this project, this
# file won't be loaded nor affect the parent project. For this reason,
# if you want to provide default values for your application for
# 3rd-party users, it should be done in your "mix.exs" file.

# You can configure for your application as:
#
#     config :acme, key: :value
#
# And access this configuration in your application as:
#
#     Application.get_env(:acme, :key)
#
# Or configure a 3rd-party app:
#
#     config :logger, level: :info
#

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).
#
#     import_config "#{Mix.env}.exs"
config :acme, :private_key, %{
  "kty" => "EC",
  "crv" => "P-384",
  "d" => "LIK4CvzeIeISvMXhKowIaUH1gS9nxnyRwh-NpX52V2aqYTPg5adSyx6rrLdDiDX3",
  "x" => "qo9XI4pCihNEJjxcEOFmFfHI5mIC1PJF0FVd4oe5IJedNE-yLZHLLwgFbqO_jJpG",
  "y" => "GHYdi049rf2hNzbz4EDXn4Mb3s2PPro3Dbng7Q7QV-DLOWkbZ45NeMsCia2ylr7G"
}