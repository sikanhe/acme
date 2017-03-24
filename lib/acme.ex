defmodule Acme do
  @moduledoc """
  Acme client
  """
  alias Acme.{Registration, Authorization, Challenge, Error}

  defdelegate request(request, pid), to: Acme.Client

  @doc """
  Register an account on the Acme server

  Supports following options:

  * `terms_of_service_agree` - If set to `true`, you agreesto the TOS when signing up. Defaults to `false`.
  """
  @spec register(binary) :: {:ok, Registration.t} | {:error, Error.t}
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
  @spec agree_terms(Registration.t) :: {:ok, Registration.t} | {:error, Error.t}
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
  @spec fetch_registration(binary) :: {:ok, Registration.t} | {:error, Error.t}
  def fetch_registration(registration_uri) do
    %Acme.Request{
      method: :post,
      resource: "reg",
      url: registration_uri,
      payload: %{resource: "reg"}
    }
  end

  @spec authorize(binary) :: Authorization.t
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

  @spec respond_challenge(Challenge.t) :: {:ok, Challenge.t} | {:error, Error.t}
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
