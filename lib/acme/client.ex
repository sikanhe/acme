defmodule Acme.Client do
  alias JOSE.{JWK, JWS}

  @client_version Mix.Project.config[:version]
  @default_connect_timeout 10_000
  @default_recv_timeout 20_000

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

  defmodule InvalidPrivateKeyError do
    defexception message: """
      You must pass a valid private key to connect to an Acme server
    """
  end

  defmodule ConnectionError do
    defexception [:message]
  end

  @doc """
  Start the Acme client.

  Supports following options:

  * `server_url` - The Acme server url
  * `private_key` - A private_key either in PEM format or as a JWK map, this is
  required unless you use `private_key_file` option
  * `private_key_file` - Instead of a private key map/pem value, you can also pass
  a private key file path
  * `connect_timeout` - Timeout in milliseconds for establishing a request connection
  * `recv_timeout` - Timeout in milliseconds for receiving the response for a request
  """
  def start_link(opts) do
    server_url = Keyword.get(opts, :server) || raise Acme.Client.MissingServerURLError
    private_key =
      if key = Keyword.get(opts, :private_key) do
        validate_private_key(key)
      else
        validate_private_key_file(Keyword.get(opts, :private_key_file))
      end
    init_state = %{
      nonce: nil,
      endpoints: nil,
      server_url: server_url,
      private_key: private_key,
      connect_timeout: Keyword.get(opts, :connect_timeout, @default_connect_timeout),
      recv_timeout: Keyword.get(opts, :recv_timeout, @default_recv_timeout)
    }
    {:ok, pid} = Agent.start_link(fn -> init_state end)
    initialize(pid)
  end

  @doc """
  (Re)Initialize a client. It calls the acme server and fetch its resource endpoints and
  nonce. Can be used to refreshed nonce when you encounter an invalid nonce error.
  """
  def initialize(pid) do
    directory_url = Path.join retrieve_server_url(pid), "directory"
    case request(%Acme.Request{method: :get, url: directory_url, resource: "directory"}, pid) do
      {:ok, endpoints} ->
        update_endpoints(pid, endpoints)
        {:ok, pid}
      error ->
        raise Acme.Client.ConnectionError, """
          Failed to connect to Acme server at: #{directory_url}, error: #{inspect error}
        """
    end
  end

  defp validate_private_key_file(nil) do
    raise Acme.Client.MissingPrivateKeyError
  end
  defp validate_private_key_file(file_path) do
    try do
      {_, jwk} =
        file_path
        |> File.read!()
        |> JWK.from_pem()
        |> JWK.to_map()
      jwk
    rescue
      _ ->
      raise Acme.Client.InvalidPrivateKeyError, message: """
        Could not correctly parse the private key at path #{file_path}
      """
    end
  end

  defp validate_private_key(nil) do
    raise Acme.Client.MissingPrivateKeyError
  end
  defp validate_private_key(jwk) when is_map(jwk) do
    try do
      %JWK{} = JWK.from_map(jwk)
      jwk
    rescue
      _ -> raise Acme.Client.InvalidPrivateKeyError
    end
  end
  defp validate_private_key(pem) when is_bitstring(pem) do
    try do
      {%{kty: _}, jwk} = pem |> JWK.from_pem() |> JWK.to_map()
      jwk
    rescue
      _ -> raise Acme.Client.InvalidPrivateKeyError
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

  def create_hackney_opts(pid, request_opts) do
    %{connect_timeout: connect_timeout, recv_timeout: recv_timeout} =
      Agent.get(pid, fn state -> state end)
    [with_body: true,
     connect_timeout: Keyword.get(request_opts, :connect_timeout, connect_timeout),
     recv_timeout: Keyword.get(request_opts, :recv_timeout, recv_timeout)]
  end

  def request(request, pid) do
    request(request, pid, [])
  end
  def request(request = %Acme.Request{url: nil, resource: resource}, pid, opts) do
    request(%{request | url: map_resource_to_url(pid, resource)}, pid, opts)
  end
  def request(%Acme.ChallengeRequest{type: type, uri: uri, token: token}, pid, opts) do
    key_auth = Acme.Challenge.create_key_authorization(token, account_key(pid))
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
    request(request, pid, opts)
  end
  def request(%Acme.Request{method: method, url: url, resource: resource, payload: payload}, pid, opts) do
    nonce = retrieve_nonce(pid)
    req_header = default_request_header()
    req_body = case method do
      :get -> <<>>
      :post ->
        payload = Poison.encode!(payload)
        private_key = account_key(pid)
        jws = sign_jws(payload, private_key, %{
          "url" => url,
          "resource" => resource,
          "nonce" => nonce
        })
    end
    hackney_opts = create_hackney_opts(pid, opts)
    response = {_, _, header, _} =
      :hackney.request(method, url, req_header, req_body, hackney_opts)
    nonce = find_response_header_value(header, "Replay-Nonce")
    update_nonce(pid, nonce)
    handle_response(response, resource)
  end

  def request!(request, pid, opts \\ []) do
    case request(request, pid, opts) do
      {:ok, struct} -> struct
      error ->
        raise Acme.Request.Error, """
          Acme Request Error!

          #{inspect error}
        """
    end
  end

  defp handle_response({:ok, 200, _header, body}, "directory") do
    {:ok, Poison.decode!(body)}
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
  defp handle_response({:ok, 201, header, _body}, "new-cert") do
    cert_url = find_response_header_value(header, "Location")
    {:ok, cert_url}
  end
  defp handle_response({:ok, 202, header, _body}, "new-cert") do
    retry_after = find_response_header_value(header, "Retry-After")
    {:accepted, retry_after: retry_after}
  end
  defp handle_response({:ok, 200, _header, cert}, "cert") do
    {:ok, cert}
  end
  defp handle_response({:ok, 200, _header, _body}, "revoke-cert") do
    :ok
  end
  defp handle_response({:ok, status, _header, body}, _) when status > 299 do
    error = Poison.decode!(body)
    {:error, Acme.Error.from_map(error)}
  end

  defp find_response_header_value(header, key) do
    Enum.find_value(header, fn
      {^key, value} -> value
      _ -> nil
    end)
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
  defp jwk_to_alg(%{"kty" => "EC", "crv" => "P-521"}), do: "ES512"
end