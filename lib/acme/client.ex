defmodule Acme.Client do
  alias JOSE.{JWK, JWS}

  @client_version Mix.Project.config[:version]

  defmodule MissingServerURLError do
    defexception message: """
      You must pass a server url to connect to an Acme server
    """
  end

  defmodule MissingPrivateKeyError do
    defexception message: """
      You must pass a valid private key to connect to an Acme server
    """
  end

  defmodule ConnectionError do
    defexception [:message]
  end

  @doc """
  Start the Acme client.

  Supports following options(both are required):

  * `server_url` - The Acme server url
  * `private_key` - A private_key either in PEM format or as a JWK map
  """
  def start_link(opts) do
    server_url = Keyword.get(opts, :server) || raise Acme.Client.MissingServerURLError
    private_key = Keyword.get(opts, :private_key) || raise Acme.Client.MissingPrivateKeyError
    init_state = %{
      nonce: nil,
      endpoints: nil,
      server_url: server_url,
      private_key: private_key
    }
    {:ok, pid} = Agent.start_link(fn -> init_state end)
    initial_request(pid)
    {:ok, pid}
  end

  defp initial_request(pid) do
    directory_url = Path.join retrieve_server_url(pid), "directory"
    case request(%Acme.Request{method: :get, url: directory_url}, pid) do
      {:ok, 200, _header, body} = response ->
        endpoints = Poison.decode!(body)
        read_and_update_nonce(pid, response)
        update_endpoints(pid, endpoints)
        {:ok, pid}
      error ->
        raise Acme.Client.ConnectionError, """
          Failed to connect to Acme server at: #{directory_url}, error: #{inspect error}
        """
    end
  end

  def retrieve_server_url(pid) do
    Agent.get(pid, fn %{server_url: server_url} -> server_url end)
  end

  def update_endpoints(pid, directory) do
    Agent.update(pid, fn state -> %{state | endpoints: directory} end)
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
    jws = sign_jws(payload, private_key, %{"resource" => resource, "nonce" => nonce})
    body = Poison.encode!(jws)
    hackney_opts = [with_body: true]
    response = :hackney.request(method, url, header, body, hackney_opts)
    read_and_update_nonce(pid, response)
    handle_response(response, resource)
  end

  def request!(request, pid) do
    case request(request, pid) do
      {:ok, struct} -> struct
      error ->
        raise Acme.Request.Error, """
          Acme Request Error!

          #{inspect error}
        """
    end
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
    Agent.get(pid, fn %{endpoints: endpoints} ->
      case Map.fetch(endpoints, resource) do
        {:ok, url} -> url
        _ -> raise Acme.Request.Error, """
            No endpoint found for the resource `#{resource}` on the Acme server
          """
      end
    end)
  end

  defp read_and_update_nonce(pid, {_, _, header, _}) do
    Enum.find_value(header, fn
      {"Replay-Nonce", nonce} -> update_nonce(pid, nonce)
      _ -> nil
    end)
  end

  @doc """
  Encodes a payload into JWS map with a private key and a replay-nonce.
  """
  def sign_jws(payload, private_key, extra_protected_header \\ %{}) do
    {_, jwk} = JWK.to_public_map(private_key)
    protected = %{
      "alg" => jwk_to_alg(jwk),
      "jwk" => jwk
    } |> Map.merge(extra_protected_header)
    {_, jws} = JWS.sign(private_key, payload, protected)
    jws
  end

  defp jwk_to_alg(%{"kty" => "RSA"}), do: "RS256"
  defp jwk_to_alg(%{"kty" => "EC", "crv" => "P-256"}), do: "ES256"
  defp jwk_to_alg(%{"kty" => "EC", "crv" => "P-384"}), do: "ES384"
  defp jwk_to_alg(%{"kty" => "EC", "crv" => "P-512"}), do: "ES512"
end