defmodule Acme.OpenSSL do
  @moduledoc """
  Helper module for generating private keys and CSR by calling out
  to OpenSSL
  """

  def openssl(args) do
    case System.cmd("openssl", args, stderr_to_stdout: true) do
      {output, 0} -> {:ok, output}
      {error, 1} -> {:error, error}
    end
  end

  @rsa_key_sizes [2048, 3072, 4096]
  @ec_curves [:prime256v1, :secp384r1]

  def generate_key({:rsa, size}, key_path) when size in @rsa_key_sizes do
    with {:ok, _} <- openssl(~w(genrsa -out #{key_path} #{size})) do
      {:ok, key_path}
    end
  end

  def generate_key({:ec, curve}, key_path) when curve in @ec_curves do
    with {:ok, _} <- openssl(~w(ecparam -name #{curve} -genkey -out #{key_path})) do
      {:ok, key_path}
    end
  end

  def generate_key({:rsa, size}) when size in @rsa_key_sizes do
    openssl(~w(genrsa #{size}))
  end

  def generate_key({:ec, curve}) when curve in @ec_curves do
    openssl(~w(ecparam -name #{curve} -genkey))
  end

  @doc """
  Take a csr path and verify the signature, optional argument

  # Example
      {:ok, output} = Acme.OpenSSL.verify_csr("/path/to/your/csr.der")
      #=> {:ok, "verify OK\n"}

      {:ok, output} = Acme.OpenSSL.verify_csr("/path/to/your/csr.pem", "PEM")
      #=> {:ok, "verify OK\n"}
  """
  def verify_csr(csr_path, inform \\ "DER") do
    Acme.OpenSSL.openssl(~w(
      req
      -noout
      -text
      -verify
      -in
      #{csr_path}
      -inform
      #{inform}
    ))
  end

  @doc """
  Take a private key path and a subject map, generate a
  new signed SR in DER format.

  # Example
      subject = %{
        common_name: "example.acme.com",
        organization_name: "Acme INC.",
        organizational_unit: "HR",
        locality_name: "New York",
        state_or_province: "NY",
        country_name: "United States"
      }

      {:ok, csr} = Acme.OpenSSL.generate_csr("/path/to/your/private_key.pem", subject)
      #=> {:ok, <<DER-encoded CSR>>

      {:ok, csr} = Acme.OpenSSL.generate_csr("/path/to/your/private_key.pem", subject, "/path/to/csr.conf")
      #=> {:ok, <<DER-encoded CSR>>
  """
  def generate_csr(private_key_path, subject, csr_config_path \\ nil) do
    openssl_args = [
      "req",
      "-new",
      "-sha256",
      "-nodes",
      "-key",
      private_key_path,
      "-subj",
      format_subject(subject),
      "-outform",
      "DER"
    ]

    case csr_config_path do
      nil -> Acme.OpenSSL.openssl(openssl_args)
      _ -> Acme.OpenSSL.openssl(openssl_args ++ ["-config", csr_config_path])
    end
  end

  @subject_keys %{
    common_name: "CN",
    country_name: "C",
    organization_name: "O",
    organizational_unit: "OU",
    state_or_province: "ST",
    locality_name: "L"
  }

  defp format_subject(subject) do
    subject
    |> Enum.map(fn {k, v} ->
         "/#{@subject_keys[k]}=#{v}"
       end)
    |> Enum.join()
  end
end
