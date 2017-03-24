defmodule Acme do
  @moduledoc """
  Acme client
  """
  alias Acme.{Client, Registration, Authorization, Error}

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

    url = Client.map_resouce_to_url("new-reg")
    Client.request(url, payload)
    |> Client.handle_response("new-reg")
  end

  def fetch_registration do
    url = Client.map_resouce_to_url("new-reg")
    Client.request(url, %{})
  end

  @doc """
  Agree to the TOS after registration
  """
  @spec agree_terms(Registration.t) :: :ok | {:error, term}
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
    url = Client.map_resouce_to_url("new-authz")
    Client.request(url, payload)
    |> Client.handle_response("new-authz")
  end
end
