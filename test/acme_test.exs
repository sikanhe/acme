defmodule AcmeTest do
  use ExUnit.Case
  doctest Acme

  setup do
    {_, private_key} = JOSE.JWS.generate_key(%{"alg" => "ES256"}) |> JOSE.JWK.to_map()
    test_server = "https://acme-staging.api.letsencrypt.org"
    Acme.Request.start_link(server: test_server, private_key: private_key)
  end

  test "register account" do
    assert {:ok, %Acme.Registration{}} = Acme.register("mailto:example@gmail.com")
  end

  test "register account failed" do
    assert {:error, %Acme.Error{}} = Acme.register("abc")
  end

  test "new authorization" do
    assert {:ok, %Acme.Registration{} = reg} = Acme.register("mailto:example@gmail.com")
    assert {:ok, _} = Acme.agree_terms(reg)
    assert {:ok, %Acme.Authorization{}} = Acme.authorize("sikanhe.com")
  end
end
