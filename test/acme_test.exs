defmodule AcmeTest do
  use ExUnit.Case, async: true
  doctest Acme

  setup do
    {_, private_key} = JOSE.JWS.generate_key(%{"alg" => "ES256"}) |> JOSE.JWK.to_map()
    test_server = "https://acme-staging.api.letsencrypt.org"
    {:ok, pid} = Acme.Client.start_link(server: test_server, private_key: private_key)
    {:ok, %{client: pid}}
  end

  def prepare_account(client) do
    {:ok, %Acme.Registration{} = reg} = Acme.register("mailto:example@gmail.com") |> Acme.request(client)
    {:ok, %Acme.Registration{}}  = Acme.agree_terms(reg) |> Acme.request(client)
  end

  test "register account", %{client: client} do
    assert {:ok, reg = %Acme.Registration{uri: reg_uri}} = Acme.register("mailto:example@gmail.com") |> Acme.request(client)
    Acme.agree_terms(reg) |> Acme.request(client)
    assert {:ok, %Acme.Registration{}} = Acme.fetch_registration(reg_uri) |> Acme.request(client)
  end

  test "register account failed", %{client: client} do
    assert {:error, %Acme.Error{}} = Acme.register("abc") |> Acme.request(client)
  end

  test "new authorization", %{client: client} do
    prepare_account(client)
    assert {:ok, %Acme.Authorization{}} = Acme.authorize("sikanhe.com") |> Acme.request(client)
  end

  test "respond to challenge", %{client: client} do
    prepare_account(client)
    {:ok, %Acme.Authorization{challenges: challenges}} = Acme.authorize("challengetest.com") |> Acme.request(client)
    assert {:ok, %Acme.Challenge{status: "pending"}} = Acme.respond_challenge(List.first(challenges)) |> Acme.request(client)
  end

  test "get a new certificate", %{client: client} do
    prepare_account(client)
    assert {:error, %Acme.Error{status: 400, detail: err_detail}} = Acme.new_certificate("abc") |> Acme.request(client)
    assert err_detail =~ "certificate request"
  end
end
