defmodule Acme.Challenge do
  defstruct [:token,
             :status,
             :type,
             :uri]

  def from_map(%{
    "type" => type,
    "status" => status,
    "uri" => uri,
    "token" => token
  }) do
    %__MODULE__{
      type: type,
      status: status,
      uri: uri,
      token: token
    }
  end
end
