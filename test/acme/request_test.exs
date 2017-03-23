defmodule Acme.RequestTest do
  use ExUnit.Case
  alias Acme.{Request}
  alias JOSE.{JWK, JWS}

  test "encode payload as JWS" do
    payload = %{"hello" => "world"} |> Poison.encode!
    nonce = "abc"
    alg = "ES256"
    {_, private_key} = JOSE.JWS.generate_key(%{"alg" => alg}) |> JWK.to_map()
    jwk_public = private_key |> JWK.to_public()
    jws = Request.encode_payload(payload, private_key, nonce)
    # Check if protected contains nonce
    protected = JWS.peek_protected(jws) |> Poison.decode!
    assert protected["nonce"] == nonce
    assert protected["alg"] == alg
    assert JWS.peek_payload(jws) == payload
    # Verify it was signed correctly
    compact = JWS.compact(jws)
    assert JWS.verify_strict(jwk_public, [alg], compact) |> elem(0) == true
  end
end