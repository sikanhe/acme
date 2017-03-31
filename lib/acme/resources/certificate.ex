defmodule Acme.Certificate do
  defstruct [:x509,
             :x509_chain,
             :der,
             :pem]

  def from_der(der) do
    %__MODULE__{
      der: der,
      pem: to_pem(der)
    }
  end

  def to_pem(der) do

  end
end
