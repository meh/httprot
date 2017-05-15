#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule HTTProt do
  defmacro __using__(_opts) do
    quote do
      alias HTTProt, as: HTTP
    end
  end

  alias HTTProt.Request, as: R

  Enum.each [:get, :head, :delete], fn name ->
    def unquote(name)(uri, headers \\ []) do
      with { :ok, request } <- R.open(unquote(name), uri),
           { :ok, request } <- R.headers(request, headers)
      do
        request |> R.send
      else
        { :error, reason } ->
          { :error, reason }
      end
    end

    def unquote(to_string(name) <> "!" |> String.to_atom)(uri, headers \\ []) do
      R.open!(unquote(name), uri) |> R.headers!(headers) |> R.send!
    end
  end

  Enum.each [:post, :put], fn name ->
    def unquote(name)(uri, data, headers \\ []) do
      with { :ok, request } <- R.open(unquote(name), uri),
           { :ok, request } <- R.headers(request, headers)
      do
        request |> R.send(data)
      else
        { :error, reason } ->
          { :error, reason }
      end
    end

    def unquote(to_string(name) <> "!" |> String.to_atom)(uri, data, headers \\ []) do
      R.open!(unquote(name), uri) |> R.headers!(headers) |> R.send!(data)
    end
  end
end
