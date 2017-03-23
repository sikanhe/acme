defmodule Acme.Error do
  defstruct [:type, :detail, :status]

  def from_map(map) do
    %__MODULE__{
      type: map["type"],
      status: map["status"],
      detail: map["detail"]
    }
  end
end