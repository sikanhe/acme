defmodule Acme.ClientTest do
  use ExUnit.Case, async: true
  alias Acme.{Client}
  alias JOSE.{JWK, JWS}
  doctest Acme.Client

  test "encode payload as JWS" do
    payload = "hello world"
    nonce = "PqwemD"
    alg = "ES256"
    {_, private_key} = JOSE.JWS.generate_key(%{"alg" => alg}) |> JWK.to_map()
    jwk_public = private_key |> JWK.to_public()
    jws = Client.sign_jws(payload, private_key, %{"nonce" => nonce})
    # Check if protected contains nonce
    protected = JWS.peek_protected(jws) |> Jason.decode!()
    assert protected["nonce"] == nonce
    assert protected["alg"] == alg
    assert JWS.peek_payload(jws) == payload
    # Verify it was signed correctly
    assert JWS.verify_strict(jwk_public, [alg], jws) |> elem(0) == true
  end

  test "missing server url" do
    assert_raise Acme.Client.MissingServerURLError, fn ->
      Acme.Client.start_link([])
    end
  end

  test "missing private key" do
    assert_raise Acme.Client.MissingPrivateKeyError, fn ->
      Acme.Client.start_link(server: "abc.com")
    end
  end

  test "invalid private key" do
    assert_raise Acme.Client.InvalidPrivateKeyError, fn ->
      Acme.Client.start_link(server: "abc.com", private_key: "abc.com")
    end

    assert_raise Acme.Client.InvalidPrivateKeyError, fn ->
      Acme.Client.start_link(server: "abc.com", private_key: %{})
    end

    assert_raise Acme.Client.InvalidPrivateKeyError, fn ->
      Acme.Client.start_link(server: "abc.com", private_key_file: "invalid/path")
    end

    tmp_dir = Path.join(System.tmp_dir!(), "acme_test.pem")
    {:ok, key_file} = Acme.OpenSSL.generate_key({:rsa, 2048}, tmp_dir)
    {:ok, key} = Acme.OpenSSL.generate_key({:rsa, 2048})
    server = "https://acme-staging.api.letsencrypt.org"

    assert {:ok, _pid} = Acme.Client.start_link(server: server, private_key: key)
    assert {:ok, _pid} = Acme.Client.start_link(server: server, private_key_file: key_file)
  end
end
