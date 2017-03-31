defmodule Acme.OpenSSLTest do
  use ExUnit.Case, async: true
  alias Acme.OpenSSL

  def gen_key_path do
   name = :crypto.strong_rand_bytes(8) |> Base.url_encode64 |> binary_part(0, 8)
   Path.join System.tmp_dir!, "#{name}.pem"
  end

  for size <- [2048, 3072, 4096] do
    test "generate RSA keys, size: #{size}" do
      assert {:ok, key} = OpenSSL.generate_key({:rsa, unquote(size)})
      assert key =~ "-----BEGIN RSA PRIVATE KEY-----"
      key_path = gen_key_path()
      assert {:ok, _} = OpenSSL.generate_key({:rsa, unquote(size)}, key_path)
      assert File.read!(key_path) =~ "-----BEGIN RSA PRIVATE KEY-----"
    end
  end

  for curve <- [:prime256v1, :secp384r1] do
    test "generate EC, curve: #{curve}" do
      assert {:ok, key} = OpenSSL.generate_key({:ec, unquote(curve)})
      assert key =~ "-----BEGIN EC PRIVATE KEY-----"
      key_path = gen_key_path()
      assert {:ok, _} = OpenSSL.generate_key({:ec, unquote(curve)}, key_path)
      assert File.read!(key_path) =~ "-----BEGIN EC PRIVATE KEY-----"
    end
  end

  test "generate a csr" do
    key_path = gen_key_path()
    {:ok, _} = OpenSSL.generate_key({:ec, :secp384r1}, key_path)
    assert {:ok, _csr_der} = OpenSSL.generate_csr(key_path, %{
      common_name: "acme.com"
    })
  end
end