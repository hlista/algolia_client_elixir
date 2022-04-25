defmodule Algolia.Error.AlgoliaProtocolError do
  defexception [:code, :message]

  def message(exception) do
    "#{exception.code}: #{exception.message}"
  end
end