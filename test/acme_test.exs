defmodule AcmeTest do
  use ExUnit.Case
  doctest Acme

  setup do
    {_, private_key} = JOSE.JWS.generate_key(%{"alg" => "ES256"}) |> JOSE.JWK.to_map()
    test_server = "https://acme-staging.api.letsencrypt.org"
    Acme.Client.start_link(server: test_server, private_key: private_key)
  end

  def prepare_account do
    {:ok, %Acme.Registration{} = reg} = Acme.register("mailto:example@gmail.com")
    Acme.agree_terms(reg)
  end

  test "register account" do
    assert {:ok, reg = %Acme.Registration{uri: reg_uri}} = Acme.register("mailto:example@gmail.com")
    Acme.agree_terms(reg)
    assert {:ok, %Acme.Registration{}} = Acme.fetch_registration(reg_uri)
  end

  test "register account failed" do
    assert {:error, %Acme.Error{}} = Acme.register("abc")
  end

  test "new authorization" do
    prepare_account()
    assert {:ok, %Acme.Authorization{}} = Acme.authorize("sikanhe.com")
  end

  test "respond to challenge" do
    prepare_account()
    {:ok, %Acme.Authorization{challenges: challenges}} = Acme.authorize("challengetest.com")
    assert {:ok, %Acme.Challenge{status: "pending"}} = Acme.respond_challenge(List.first(challenges))
  end

  test "get a new certificate" do
    prepare_account()
    assert {:error, %Acme.Error{status: 400, detail: err_detail}} = Acme.new_certificate("abc")
    assert err_detail =~ "certificate request"
  end
end
