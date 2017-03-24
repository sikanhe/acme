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

    {:ok, pid} = Agent.start_link(fn -> init_state end)
    initial_request(pid)
    {:ok, pid}
  end

  defp initial_request(pid) do
    directory_url = Path.join retrieve_server_url(pid), "directory"
    case request(%Acme.Request{method: :get, url: directory_url}, pid) do
      {:ok, 200, _header, body} = response ->
        directory = Poison.decode!(body)
        read_and_update_nonce(pid, response)
        update_directory(pid, directory)
        {:ok, pid}
      error ->
        raise "Failed to connect to Acme server at: #{directory_url}, error: #{inspect error}"
    end
  end

  def retrieve_server_url(pid) do
    Agent.get(pid, fn %{server_url: server_url} -> server_url end)
  end

  def update_directory(pid, directory) do
    Agent.update(pid, fn state -> %{state | directory: directory} end)
  end

  def account_key(pid) do
    Agent.get(pid, fn %{private_key: private_key} -> private_key end)
  end

  def retrieve_nonce(pid) do
    Agent.get(pid, fn %{nonce: nonce} -> nonce end)
  end

  def update_nonce(pid, new_nonce) do
    Agent.update(pid, fn state -> %{state | nonce: new_nonce} end)
  end

  defp default_request_header do
    [{"User-Agent", "Elixir Acme Client #{@client_version}"},
     {"Cache-Control", "no-store"}]
  end

  def request(request = %Acme.Request{url: nil, resource: resource}, pid) do
    request(%{request | url: map_resource_to_url(pid, resource)}, pid)
  end
  def request(%Acme.Request{method: :get, url: url}, pid) do
    header = default_request_header()
    hackney_opts = [with_body: true]
    response = :hackney.request(:get, url, header, <<>>, hackney_opts)
    read_and_update_nonce(pid, response)
    response
  end
  def request(%Acme.ChallengeRequest{type: type, uri: uri, token: token}, pid) do
    thumbprint = JOSE.JWK.thumbprint(account_key(pid))
    key_auth = "#{token}.#{thumbprint}"
    request = %Acme.Request{
      method: :post,
      resource: "challenge",
      url: uri,
      payload: %{
        resource: "challenge",
        type: type,
        keyAuthorization: key_auth
      }
    }
    request(request, pid)
  end
  def request(%Acme.Request{method: method, url: url, resource: resource, payload: payload}, pid) do
    header = default_request_header()
    nonce = retrieve_nonce(pid)
    payload = Poison.encode!(payload)
    private_key = account_key(pid)
    body = encode_payload(payload, private_key, nonce)
    hackney_opts = [with_body: true]
    response = :hackney.request(method, url, header, body, hackney_opts)
    read_and_update_nonce(pid, response)
    handle_response(response, resource)
  end

  defp handle_response({:ok, 201, header, body}, "new-reg") do
    response = Poison.decode! body
    {:ok, Acme.Registration.from_response(header, response)}
  end
  defp handle_response({:ok, 202, header, body}, "reg") do
    response = Poison.decode! body
    {:ok, Acme.Registration.from_response(header, response)}
  end
  defp handle_response({:ok, 201, _header, body}, "new-authz") do
    {:ok, Acme.Authorization.from_map(Poison.decode!(body))}
  end
  defp handle_response({:ok, 202, _header, body}, "challenge") do
    challenge = Poison.decode!(body)
    {:ok, Acme.Challenge.from_map(challenge)}
  end
  defp handle_response({:ok, status, _header, body}, _) when status > 299 do
    error = Poison.decode!(body)
    {:error, Acme.Error.from_map(error)}
  end

  defp map_resource_to_url(pid, resource) do
    directory = Agent.get(pid, fn %{directory: directory} -> directory end)
    case Map.fetch(directory, resource) do
      {:ok, url} -> url
      _ -> raise "No url for resource #{resource} on this Acme server"
    end
  end

  defp read_and_update_nonce(pid, {_, _, header, _}) do
    Enum.find_value(header, fn
      {"Replay-Nonce", nonce} -> update_nonce(pid, nonce)
      _ -> nil
    end)
  end

  @doc """
  Encodes a payload with a private key and a replay-nonce.
  Takes a
  """
  def encode_payload(payload, private_key, nonce) do
    {_, jwk} = JWK.to_public_map(private_key)
    protected = %{
      "alg" => jwk_to_alg(jwk),
      "jwk" => jwk,
      "nonce" => nonce
    }
    {_, jws} = JWS.sign(private_key, payload, protected)
    Poison.encode! jws
  end

  defp jwk_to_alg(%{"kty" => "RSA"}), do: "RS256"
  defp jwk_to_alg(%{"kty" => "EC", "crv" => "P-256"}), do: "ES256"
  defp jwk_to_alg(%{"kty" => "EC", "crv" => "P-384"}), do: "ES384"
  defp jwk_to_alg(%{"kty" => "EC", "crv" => "P-512"}), do: "ES512"
end