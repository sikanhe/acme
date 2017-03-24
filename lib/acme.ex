defmodule Acme do
  @moduledoc """
  Acme client
  """
  alias Acme.{Registration, Authorization, Challenge, Error}

  @spec request(Request.t, pid) :: {:ok, term} | {:error, Error.t}
  defdelegate request(request, pid), to: Acme.Client

  @doc """
  Register an account on the Acme server.

  ## Example:
  ```
  {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
  Acme.register("mailto:acme@example.com") |> Acme.request(conn)
  #=> {:ok, %Registration{...}}
  ```
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
  Agree to the TOS after registration. Takes a Registration struct
  often received from calling &Acme.register/1. Returns {:ok, Registration}
  or {:error, Error}

  ## Example:
  ```
  {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
  {:ok, registration} = Acme.register("mailto:acme@example.com") |> Acme.request(conn)
  Acme.agree_terms(registration) |> Acme.request(conn)
  #=> {:ok, %Registration{...}}
  ```
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

  ## Example:
  ```
  Let's say we have a Registration struct from before:
  registration = %Registration{uri:...}

  And we want to refetch registation again:

  {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
  Acme.fetch_registration(registration.uri) |> Acme.request(conn)
  #=> {:ok, %Registraction{...}}
  ```
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

  @doc """
  Request an authorization for a domain

  ## Example:
  ```
  {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
  Acme.authorize("quick@example.com") |> Acme.request(conn)
  #=> {:ok, %Authorization{status: "pending", challenges: [...], ...}}
  ```
  """
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

  @doc """
  Build a request to respond to a specific challenge. Takes a Acme.Challenge struct
  and returns a Acme.Request struct

  ## Example:
  ```
  challenge = %Acme.Challenge{type: "http-01", token: ...}
  {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
  request = Acme.respond_challenge(challenge) |> Acme.request(conn)
  #=> {:ok, %Challenge{status: "pending", ...}}
  ```
  """
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
