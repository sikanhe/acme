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

  @doc """
  Creates a KeyAuthorization from a challenge token and a account key
  in jwk
  """
  def create_key_authorization(token, jwk) do
    thumbprint = JOSE.JWK.thumbprint(jwk)
    "#{token}.#{thumbprint}"
  end
end
