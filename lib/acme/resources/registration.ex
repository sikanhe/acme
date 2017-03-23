defmodule Acme.Registration do
  defstruct [:id, :key, :contact, :url, :status, :term_of_service_url]

  def from_response(header, response) do
    %Acme.Registration{
      id: response["id"],
      key: response["key"],
      contact: response["contact"],
      status: response["Status"],
      url: find_reg_url(header),
      term_of_service_url: find_terms_url(header)
    }
  end

  def find_terms_url(header) do
    Enum.find_value(header, fn {_, value} ->
      if value =~ "terms" do
        [link] = Regex.run(~r/<(.*)>/, value, capture: :all_but_first)
        link
      end
    end)
  end

  def find_reg_url(header) do
    Enum.find_value(header, fn {key, value} ->
      if key == "Location" do
        uri = URI.parse(value)
        URI.to_string(uri)
      end
    end)
  end

  def get_terms(%__MODULE__{term_of_service_url: url}) do
    {:ok, 200, _headers, body} = Acme.request(:get, url, <<>>)
    {:ok, body}
  end

  def agree_terms(%__MODULE__{term_of_service_url: terms_url}) do
    Acme.request(:post, "reg", %{resource: "reg", agreement: terms_url})
    Acme.Request.request("reg",  %{resource: "reg", agreement: terms_url})
  end
end
