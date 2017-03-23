defmodule Acme do
  @moduledoc """
  Acme client
  """
  alias Acme.{Request, Registration, Authorization, Error}

  @doc """
  Register an account on the Acme server
  """
  @spec register(binary) :: {:ok, Registration.t} | {:error, Error.t}
  def register(contact) do
    payload = %{
      "resource" => "new-reg",
      "contact" => [contact]
    }

     url = Request.map_action_to_url("new-reg")
    Request.request(url, payload)
    |> Request.handle_response("new-reg")
  end

  def fetch_registration do
    # Request.request("new-reg", payload)
  end

  @doc """
  Agree to the TOS after registration
  """
  @spec agree_terms(Registration.t) :: :ok | {:error, term}
  def agree_terms(%Registration{term_of_service_url: terms_url, url: reg_url}) do
    Acme.Request.request(reg_url, %{resource: "reg", agreement: terms_url})
    |> Request.handle_response("reg")
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
    url = Request.map_action_to_url("new-authz")
    Request.request(url, payload)
    |> Request.handle_response("new-authz")
  end

  @spec fetch_authorization(binary) :: Authorization.t
  def fetch_authorization(uri) do

  end

  def request_certificate(names: domains) when is_list(domains) do

  end
end
