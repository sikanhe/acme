defmodule Acme do
  @moduledoc """
  Acme client
  """
  alias Acme.{Registration, Authorization, Challenge, Error}

  @spec request(Request.t, pid) :: {:ok, term} | {:error, Error.t}
  defdelegate request(request, pid), to: Acme.Client

  @doc """
  Register an account on the Acme server

  Supports following options:

  * `terms_of_service_agree` - If set to `true`, you agreesto the TOS when signing up. Defaults to `false`.
  """
  @spec register(binary) :: Acme.Request.t
  def register(contact) do
    %Acme.Request{
      method: :post,
      resource: "new-reg",
      payload: %{
        resource: "new-reg",
        contact: [contact]
      }
    }
  end

  @doc """
  Agree to the TOS after registration
  """
  @spec agree_terms(Registration.t) :: Acme.Request.t
  def agree_terms(%Registration{term_of_service_uri: terms_uri, uri: reg_uri}) do
    %Acme.Request{
      method: :post,
      resource: "reg",
      url: reg_uri,
      payload: %{resource: "reg", agreement: terms_uri}
    }
  end

  @doc """
  Refetch a registration by its uri
  """
  @spec fetch_registration(binary) :: Acme.Request.t
  def fetch_registration(registration_uri) do
    %Acme.Request{
      method: :post,
      resource: "reg",
      url: registration_uri,
      payload: %{resource: "reg"}
    }
  end

  @spec authorize(binary) :: Acme.Request.t
  def authorize(domain) do
    %Acme.Request{
      method: :post,
      resource: "new-authz",
      payload: %{
        resource: "new-authz",
        identifier: %{
          type: "dns",
          value: domain
        }
      }
    }
  end

  @spec respond_challenge(Challenge.t) :: Acme.Request.t
  def respond_challenge(%Challenge{type: type, uri: uri, token: token}) do
    %Acme.ChallengeRequest{
      uri: uri,
      type: type,
      token: token
    }
  end

  def new_certificate(csr) do
    %Acme.Request{
      method: :post,
      resource: "new-cert",
      payload: %{
        resource: "new-cert",
        csr: Base.url_decode64(csr)
      }
    }
  end
end
