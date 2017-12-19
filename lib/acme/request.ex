defmodule Acme.Request do
  @moduledoc false
  defstruct [:method, :resource, :url, :payload]

  defmodule Error do
    defexception [:message]
  end
end
