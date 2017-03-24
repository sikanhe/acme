defmodule Acme do
  @moduledoc """
  Acme client
  """
  alias Acme.{Client, Registration, Authorization, Challenge, Error}

  defdelegate request(url, payload), to: Acme.Client
  defdelegate request(url, payload, opts), to: Acme.Client

  @doc """
  Register an account on the Acme server

  Supports following options:

  * `terms_of_service_agree` - If set to `true`, you agreesto the TOS when signing up. Defaults to `false`.
  """
  @spec register(binary) :: {:ok, Registration.t} | {:error, Error.t}
  @spec register(binary, Keyword.t) :: {:ok, Registration.t} | {:error, Error.t}
  def register(contact, opts \\ []) do
    payload = %{
      resource: "new-reg",
      contact: [contact]
    }
    url = Client.map_resource_to_url("new-reg")
    response =
      Client.request(:post, url, payload)
      |> Client.handle_response("new-reg")

    if Keyword.get(opts, :term_of_service_agree) do
      with {:ok, reg} <- response, do: agree_terms(reg)
    else
      response
    end
  end

  @doc """
  Agree to the TOS after registration
  """
  @spec agree_terms(Registration.t) :: {:ok, Registration.t} | {:error, Error.t}
  def agree_terms(%Registration{term_of_service_uri: terms_uri, uri: reg_uri}) do
    Acme.Client.request(:post, reg_uri, %{resource: "reg", agreement: terms_uri})
    |> Client.handle_response("reg")
  end

  @doc """
  Refetch a registration by its uri
  """
  @spec fetch_registration(binary) :: {:ok, Registration.t} | {:error, Error.t}
  def fetch_registration(registration_uri) do
    Client.request(:post, registration_uri, %{resource: "reg"})
    |> Client.handle_response("reg")
  end

  @spec authorize(binary) :: Authorization.t
  def authorize(domain) do
    payload = %{
      resource: "new-authz",
      identifier: %{
        type: "dns",
        value: domain
      }
    }
    url = Client.map_resource_to_url("new-authz")
    Client.request(:post, url, payload)
    |> Client.handle_response("new-authz")
  end

  @spec respond_challenge(Challenge.t) :: {:ok, Challenge.t} | {:error, Error.t}
  def respond_challenge(%Challenge{type: type, uri: uri, token: token}) do
    thumbprint = JOSE.JWK.thumbprint(Client.account_key())
    key_auth = "#{token}.#{thumbprint}"
    payload = %{
      resource: "challenge",
      type: type,
      keyAuthorization: key_auth
    }

    Client.request(:post, uri, payload)
    |> Client.handle_response("challenge")
  end

  def new_certificate(csr) do
    payload = %{
      resource: "new-cert",
      csr: Base.url_decode64(csr)
    }

    url = Client.map_resource_to_url("new-cert")
    Client.request(:post, url, payload)
    |> Client.handle_response("new-cert")
  end
end
