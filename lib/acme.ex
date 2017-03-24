defmodule Acme do
  @moduledoc """
  Acme client
  """
  alias Acme.{Client, Registration, Authorization, Challenge, Error}

  defdelegate request(url, payload), to: Acme.Client
  defdelegate request(url, payload, opts), to: Acme.Client

  @doc """
  Register an account on the Acme server
  """
  @spec register(binary) :: {:ok, Registration.t} | {:error, Error.t}
  def register(contact) do
    payload = %{
      "resource" => "new-reg",
      "contact" => [contact]
    }
    url = Client.map_resource_to_url("new-reg")
    Client.request(url, payload)
    |> Client.handle_response("new-reg")
  end

  @doc """
  Agree to the TOS after registration
  """
  @spec agree_terms(Registration.t) :: {:ok, Registration.t} | {:error, Error.t}
  def agree_terms(%Registration{term_of_service_url: terms_url, url: reg_url}) do
    Acme.Client.request(reg_url, %{resource: "reg", agreement: terms_url})
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
    Client.request(url, payload)
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

    Client.request(uri, payload)
    |> Client.handle_response("challenge")
  end

  def new_certificate(csr) do
    payload = %{
      resource: "new-cert",
      csr: Base.url_decode64(csr)
    }

    url = Client.map_resource_to_url("new-cert")
    Client.request(url, payload)
    |> Client.handle_response("new-cert")
  end
end
