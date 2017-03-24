defmodule Acme.Client do
  alias JOSE.{JWK, JWS}

  @client_version Mix.Project.config[:version]

  @doc """
  Start the Acme client.

  Supports following options(both are required):

  * `server_url` - The Acme server url
  * `private_key` - A private_key either in PEM format or as a JWK map
  """
  def start_link(opts) do
    init_state = %{
      nonce: nil,
      directory: nil,
      server_url: Keyword.get(opts, :server),
      private_key: Keyword.get(opts, :private_key)
    }

    if !init_state.server_url,
      do: raise "You must pass an Acme server_url to connect to an Acme server"
    if !init_state.private_key,
      do:  raise "You must pass a private key to connect to an Acme server"

    Agent.start_link(fn -> init_state end, name: __MODULE__)
    initial_request()
  end

  def retrieve_server_url do
    Agent.get(__MODULE__, fn %{server_url: server_url} -> server_url end)
  end

  def update_directory(directory) do
    Agent.update(__MODULE__, fn state -> %{state | directory: directory} end)
  end

  def account_key do
    Agent.get(__MODULE__, fn %{private_key: private_key} -> private_key end)
  end

  def retrieve_nonce do
    Agent.get(__MODULE__, fn %{nonce: nonce} -> nonce end)
  end

  def update_nonce(new_nonce) do
    Agent.update(__MODULE__, fn state -> %{state | nonce: new_nonce} end)
  end

  defp default_request_header do
    [{"User-Agent", "Elixir Acme Client #{@client_version}"},
     {"Cache-Control", "no-store"}]
  end

  defp initial_request() do
    directory_url = Path.join retrieve_server_url(), "directory"
    case :hackney.get(directory_url, default_request_header(), <<>>, [with_body: true]) do
      {:ok, 200, header, body} = response ->
        directory = Poison.decode!(body)
        read_and_update_nonce(response)
        update_directory(directory)
      error ->
        raise "Failed to connect to Acme server at: #{directory_url}, error: #{inspect error}"
    end
  end

  def map_resource_to_url(action) do
    directory = Agent.get(__MODULE__, fn %{directory: directory} -> directory end)
    case Map.fetch(directory, action) do
      {:ok, url} -> url
      _ -> raise "No url for action #{action} on this Acme server"
    end
  end

  def request(url, payload, opts \\ []) do
    header = default_request_header()
    nonce = retrieve_nonce()
    payload = Poison.encode! payload
    private_key = Keyword.get(opts, :private_key, account_key())
    jws = encode_payload(payload, account_key(), nonce)
    body = Poison.encode! jws
    hackney_opts = [with_body: true] ++ opts
    response = :hackney.post(url, header, body, hackney_opts)
    read_and_update_nonce(response)
    response
  end

  def handle_response({:ok, 201, header, body}, "new-reg") do
    response = Poison.decode! body
    {:ok, Acme.Registration.from_response(header, response)}
  end
  def handle_response({:ok, 202, header, body}, "reg") do
    response = Poison.decode! body
    {:ok, Acme.Registration.from_response(header, response)}
  end
  def handle_response({:ok, 201, _header, body}, "new-authz") do
    {:ok, Acme.Authorization.from_map(Poison.decode!(body))}
  end
  def handle_response({:ok, 202, _header, body}, "challenge") do
    challenge = Poison.decode!(body)
    {:ok, Acme.Challenge.from_map(challenge)}
  end
  def handle_response({:ok, status, _header, body}, _) when status > 299 do
    error = Poison.decode!(body)
    {:error, Acme.Error.from_map(error)}
  end

  @doc """
  Fetch the Replay-Nonce value from response header
  """
  def read_and_update_nonce({_, _, header, _}) do
    Enum.find_value(header, fn
      {"Replay-Nonce", nonce} -> update_nonce(nonce)
      _ -> nil
    end)
  end

  @doc """
  Encodes a payload with a private key and a replay-nonce.
  """
  def encode_payload(payload, private_key, nonce) do
    {_, jwk} = JWK.to_public_map(private_key)
    protected = %{
      "alg" => jwk_to_alg(jwk),
      "jwk" => jwk,
      "nonce" => nonce
    }
    {_, jws} = JWS.sign(private_key, payload, protected)
    jws
  end

  defp jwk_to_alg(%{"kty" => "RSA"}), do: "RS256"
  defp jwk_to_alg(%{"kty" => "EC", "crv" => "P-256"}), do: "ES256"
  defp jwk_to_alg(%{"kty" => "EC", "crv" => "P-384"}), do: "ES384"
  defp jwk_to_alg(%{"kty" => "EC", "crv" => "P-512"}), do: "ES512"
end