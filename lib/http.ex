#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule HTTP do
  use Socket.Helpers

  Enum.each [:get, :head], fn name ->
    def unquote(name)(uri, headers \\ []) do
      case HTTP.Request.open(unquote(name), uri) do
        { :ok, request } ->
          case request.headers(headers) do
            { :ok, request } ->
              request.send

            { :error, _ } = error ->
              error
          end

        { :error, _ } = error ->
          error
      end
    end

    def unquote(to_string(name) <> "!" |> binary_to_atom)(uri, headers \\ []) do
      HTTP.Request.open!(unquote(name), uri).headers!(headers).send!
    end
  end

  Enum.each [:post, :put, :delete], fn name ->
    def unquote(name)(uri, data, headers \\ []) do
      case HTTP.Request.open(unquote(name), uri) do
        { :ok, request } ->
          case request.headers(headers) do
            { :ok, request } ->
              request.send(data)

            { :error, _ } = error ->
              error
          end

        { :error, _ } = error ->
          error
      end
    end

    def unquote(to_string(name) <> "!" |> binary_to_atom)(uri, data, headers \\ []) do
      HTTP.Request.open!(unquote(name), uri).headers!(headers).send!(data)
    end
  end
end
