defmodule Acme.Authorization do
  defstruct [:status, :identifier, :expires, :challenges]

  alias Acme.{Identifier, Challenge}

  def from_map(%{
    "expires" => expires_iso8601,
    "identifier" => identifier,
    "status" => status,
    "challenges" => challenges
  }) do
    %__MODULE__{
      status: status,
      expires: DateTime.from_iso8601(expires_iso8601),
      identifier: Identifier.from_json(identifier),
      challenges: Enum.map(challenges, &Challenge.from_map/1)
    }
  end
end