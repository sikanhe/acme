defmodule Acme do
  @moduledoc File.read!(Path.expand("./README.md"))

  @spec request(Acme.Request.t(), pid) :: {:ok, term} | {:error, Acme.Error.t()}
  defdelegate request(request, pid), to: Acme.Client
  @spec request!(Acme.Request.r(), pid) :: term
  defdelegate request!(request, pid), to: Acme.Client

  @doc """
  Builds an `%Acme.Request{}` for registering an account on the Acme server.

  When called with `&Acme.request/1`, it returns a `{:ok, %Acme.Registration{}}`
  or `{:error, %Acme.Error{}}` tuple.

  ## Example:

      {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
      Acme.register("mailto:acme@example.com") |> Acme.request(conn)
      #=> {:ok, %Registration{...}}

  """
  @spec register(binary | list) :: Acme.Request.t()
  def register(contact) when is_bitstring(contact) do
    register([contact])
  end

  def register(contact) when is_list(contact) do
    %Acme.Request{
      method: :post,
      resource: "new-reg",
      payload: %{
        resource: "new-reg",
        contact: contact
      }
    }
  end

  @doc """
  Builds an `%Acme.Request{} for Agree to the TOS after registration.
  Takes am `%Acme.Registration{}` struct often received from calling
  &Acme.register/1.

  When called with `&Acme.request/1`, it returns a `{:ok, %Acme.Registration{}}`
  or `{:error, %Acme.Error{}}` tuple.

  ## Example:

      {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
      {:ok, registration} = Acme.register("mailto:acme@example.com") |> Acme.request(conn)
      Acme.agree_terms(registration) |> Acme.request(conn)
      #=> {:ok, %Registration{...}}

  """
  @spec agree_terms(Acme.Registration.t()) :: Acme.Request.t()
  def agree_terms(%Acme.Registration{term_of_service_uri: terms_uri, uri: reg_uri}) do
    %Acme.Request{
      method: :post,
      resource: "reg",
      url: reg_uri,
      payload: %{resource: "reg", agreement: terms_uri}
    }
  end

  @doc """
  Builds an `%Acme.Request{}` for Refetch a registration by its uri.

  When called with with `&Acme.request/1`, it returns a `{:ok, %Acme.Registration{}}`
  or `{:error, %Acme.Error{}}` tuple.

  ## Example:

      We have a Registration struct from before:
      registration = %Registration{uri:...}

      And we want to refetch registation again:

      {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
      Acme.fetch_registration(registration.uri) |> Acme.request(conn)
      #=> {:ok, %Registraction{...}}

  """
  @spec fetch_registration(binary) :: Acme.Request.t()
  def fetch_registration(registration_uri) do
    %Acme.Request{
      method: :post,
      resource: "reg",
      url: registration_uri,
      payload: %{resource: "reg"}
    }
  end

  @doc """
  Builds an `%Acme.Request{}` for requesting an authorization
  for a domain.

  When called with `&Acme.request/1`, it returns a `{:ok, %Acme.Authorization{}}`
  or `{:error, %Acme.Error{}}` tuple.

  ## Example:

      {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
      Acme.authorize("quick@example.com") |> Acme.request(conn)
      #=> {:ok, %Authorization{status: "pending", challenges: [...], ...}}

  """
  @spec authorize(binary) :: Acme.Request.t()
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
  Takes an `%Acme.Challenge{}` struct and builds an `%Acme.ChallengeRequest{}` to
  respond to a specific challenge.

  When called with `&Acme.request/1`, it returns a `{:ok, %Acme.Chellenge{}}`
  or `{:error, %Acme.Error{}}` tuple.

  ## Example:

      challenge = %Acme.Challenge{type: "http-01", token: ...}
      {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
      Acme.respond_challenge(challenge) |> Acme.request(conn)
      #=> {:ok, %Challenge{status: "pending", ...}}

  """
  @spec respond_challenge(Acme.Challenge.t()) :: Acme.Request.t()
  def respond_challenge(%Acme.Challenge{type: type, uri: uri, token: token}) do
    %Acme.ChallengeRequest{
      uri: uri,
      type: type,
      token: token
    }
  end

  @doc """
  Takes an CSR in DER format and builds an `%Acme.Request{}` for a new certificate

  When called with `&Acme.request/1`, it returns a `{:ok, certificate_url}`
  or `{:error, %Acme.Error{}}` tuple.

  ## Example:

      {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
      Acme.new_certificate("5jNudRx6Ye4HzKEqT5...FS6aKdZeGsysoCo4H9P")
      |> Acme.request(conn)
      #=> {:ok, "https://example.com/acme/cert/asdf"}

  """
  def new_certificate(csr) do
    %Acme.Request{
      method: :post,
      resource: "new-cert",
      payload: %{
        resource: "new-cert",
        csr: Base.url_encode64(csr, padding: false)
      }
    }
  end

  @doc """
  Get a certificate by its URL

  ## Example:

      {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
      Acme.get_certificate("https://example.com/acme/cert/asdf")
      |> Acme.request(conn)
      #=> {:ok, <<DER-encoded certificate>>}

  """
  def get_certificate(url) do
    %Acme.Request{
      method: :get,
      url: url,
      resource: "cert"
    }
  end

  @doc """
  Takes a certificate in DER format and a reason code and builds
  an `%Acme.Request{}` to revoke a certificate. When called
  with `&Acme.request/1`, it returns either `:ok` or
  `{:error, %Acme.Error{}}`.

  Possible reason codes:

      unspecified             (0) <-- default,
      keyCompromise           (1),
      cACompromise            (2),
      affiliationChanged      (3),
      superseded              (4),
      cessationOfOperation    (5),
      certificateHold         (6),
            -- value 7 is not used
      removeFromCRL           (8),
      privilegeWithdrawn      (9),
      aACompromise           (10)

  More information about reason at:
  https://tools.ietf.org/html/rfc5280#section-5.3.1

  ## Example:

      {:ok, conn} = Acme.Client.start_link(server: ..., private_key: ...)
      Acme.revoke_certificate("5jNudRx6Ye4HzKEqT5...FS6aKdZeGsysoCo4H9P", 1)
      |> Acme.request(conn)
      #=> {:ok, "https://example.com/acme/cert/asdf"}

  """
  def revoke_certificate(certificate_der, reason \\ 0) do
    %Acme.Request{
      method: :post,
      resource: "revoke-cert",
      payload: %{
        resource: "revoke-cert",
        certificate: Base.url_encode64(certificate_der, padding: false),
        reason: reason
      }
    }
  end
end
