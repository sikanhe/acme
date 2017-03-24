defmodule Acme.Registration do
  defstruct [:id, :key, :contact, :uri, :status, :term_of_service_uri, :agreement]

  def from_response(header, response) do
    %Acme.Registration{
      id: response["id"],
      key: response["key"],
      contact: response["contact"],
      status: response["Status"],
      uri: find_reg_uri(header),
      term_of_service_uri: find_terms_uri(header),
      agreement: response["agreement"]
    }
  end

  def find_terms_uri(header) do
    Enum.find_value(header, fn {_, value} ->
      if value =~ "terms" do
        [link] = Regex.run(~r/<(.*)>/, value, capture: :all_but_first)
        link
      end
    end)
  end

  def find_reg_uri(header) do
    Enum.find_value(header, fn {key, value} ->
      if key == "Location", do: value
    end)
  end
end
