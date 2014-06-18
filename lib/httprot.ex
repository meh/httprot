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

  Enum.each [:get, :head], fn name ->
    def unquote(name)(uri, headers \\ []) do
      case R.open(unquote(name), uri) do
        { :ok, request } ->
          case request |> R.headers(headers) do
            { :ok, request } ->
              request |> R.send

            { :error, _ } = error ->
              error
          end

        { :error, _ } = error ->
          error
      end
    end

    def unquote(to_string(name) <> "!" |> String.to_atom)(uri, headers \\ []) do
      R.open!(unquote(name), uri) |> R.headers!(headers) |> R.send!
    end
  end

  Enum.each [:post, :put, :delete], fn name ->
    def unquote(name)(uri, data, headers \\ []) do
      case R.open(unquote(name), uri) do
        { :ok, request } ->
          case request |> R.headers(headers) do
            { :ok, request } ->
              request |> R.send(data)

            { :error, _ } = error ->
              error
          end

        { :error, _ } = error ->
          error
      end
    end

    def unquote(to_string(name) <> "!" |> String.to_atom)(uri, data, headers \\ []) do
      R.open!(unquote(name), uri) |> R.headers!(headers) |> R.send!(data)
    end
  end
end
