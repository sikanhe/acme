defmodule Acme.ClientTest do
  use ExUnit.Case
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
    protected = JWS.peek_protected(jws) |> Poison.decode!
    assert protected["nonce"] == nonce
    assert protected["alg"] == alg
    assert JWS.peek_payload(jws) == payload
    # Verify it was signed correctly
    compact = JWS.compact(jws)
    assert JWS.verify_strict(jwk_public, [alg], compact) |> elem(0) == true
  end

  test "missing server url" do
    assert_raise Acme.Client.MissingServerURLError, fn ->
      Acme.Client.start_link([])
    end
  end

  test "missing private key" do
    assert_raise Acme.Client.MissingPrivateKeyError, fn ->
      Acme.Client.start_link([server: "abc.com"])
    end
  end
end