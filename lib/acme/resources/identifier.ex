defmodule Acme.Identifier do
  defstruct [:type, :value]

  def from_json(%{"type" => type, "value" => value}) do
    %__MODULE__{
      type: type,
      value: value
    }
  end
end
