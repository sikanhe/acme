defmodule Acme.Error do
  defstruct [:type, :detail, :status]

  def from_map(%{
        "type" => type,
        "status" => status,
        "detail" => detail
      }) do
    %__MODULE__{
      type: type,
      status: status,
      detail: detail
    }
  end
end
