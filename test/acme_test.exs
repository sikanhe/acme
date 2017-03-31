defmodule AcmeTest do
  use ExUnit.Case, async: true
  doctest Acme

  setup do
    {:ok, key} = Acme.OpenSSL.generate_key({:rsa, 2048})
    test_server = "https://acme-staging.api.letsencrypt.org"
    {:ok, pid} = Acme.Client.start_link(server: test_server, private_key: key)
    {:ok, %{client: pid}}
  end

  def prepare_account(client) do
    {:ok, %Acme.Registration{} = reg} = Acme.register("mailto:example@gmail.com") |> Acme.request(client)
    {:ok, %Acme.Registration{}}  = Acme.agree_terms(reg) |> Acme.request(client)
    reg
  end

  test "register account", %{client: client} do
    assert {:ok, reg = %Acme.Registration{uri: reg_uri}} = Acme.register("mailto:example@gmail.com") |> Acme.request(client)
    assert {:ok, _reg} = Acme.agree_terms(reg) |> Acme.request(client)
    assert {:ok, %Acme.Registration{}} = Acme.fetch_registration(reg_uri) |> Acme.request(client)
  end

  test "register account failed", %{client: client} do
    assert {:error, %Acme.Error{}} = Acme.register("abc") |> Acme.request(client)
  end

  test "new authorization", %{client: client} do
    prepare_account(client)
    assert {:ok, %Acme.Authorization{}} =
      Acme.authorize("sikanhe.com")
      |> Acme.request(client)
  end

  test "respond to challenge", %{client: client} do
    prepare_account(client)
    {:ok, %Acme.Authorization{challenges: challenges}} =
      Acme.authorize("challengetest.com")
      |> Acme.request(client)
    assert {:ok, %Acme.Challenge{status: "pending"}} =
      Acme.respond_challenge(List.first(challenges))
      |> Acme.request(client)
  end

  test "get a new certificate", %{client: client} do
    prepare_account(client)
    key_path = Path.join System.tmp_dir!, "test_csr_ec.pem"
    {:ok, csr} = Acme.OpenSSL.generate_csr(key_path, %{common_name: "example.com"})
    assert {:error, %Acme.Error{status: err_status, detail: err_detail}} =
      Acme.new_certificate(csr)
      |> Acme.request(client)
    assert err_status == 403
    assert err_detail =~ "example.com"
  end

  test "revoke a cert", %{client: client} do
    prepare_account(client)
    cert_der = File.read!(Path.expand("./test/support/cert.der"))
    assert {:error, %Acme.Error{status: err_status, detail: err_detail}} =
      Acme.revoke_certificate(cert_der)
      |> Acme.request(client)
    assert err_status == 404
    assert err_detail == "No such certificate"
  end
end
