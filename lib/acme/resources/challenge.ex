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
  def create_key_authorization(%__MODULE__{token: token}, jwk) do
    create_key_authorization(token, jwk)
  end
  def create_key_authorization(token, jwk) do
    thumbprint = JOSE.JWK.thumbprint(jwk)
    "#{token}.#{thumbprint}"
  end

  def generate_dns_txt_record(%__MODULE__{type: "dns-01", token: token}, jwk) do
    ka = create_key_authorization(token, jwk)
    :crypto.hash(:sha256, ka)
    |> Base.url_encode64(padding: false)
  end
end
