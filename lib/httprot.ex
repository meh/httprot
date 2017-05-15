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

  alias HTTProt.{Request, Response}

  Enum.each [:get, :head, :delete], fn name ->
    @spec unquote(name)(URI.t | String.t) :: Response.t
    @spec unquote(name)(URI.t | String.t, Keyword.t) :: Response.t
    def unquote(name)(uri, headers \\ []) do
      with { :ok, request } <- Request.open(unquote(name), uri),
           { :ok, request } <- Request.headers(request, headers)
      do
        request |> Request.send
      else
        { :error, reason } ->
          { :error, reason }
      end
    end

    def unquote(to_string(name) <> "!" |> String.to_atom)(uri, headers \\ []) do
      Request.open!(unquote(name), uri) |> Request.headers!(headers) |> Request.send!
    end
  end

  Enum.each [:post, :put], fn name ->
    @spec unquote(name)(URI.t | String.t, String.t) :: Response.t
    @spec unquote(name)(URI.t | String.t, String.t, Keyword.t) :: Response.t
    def unquote(name)(uri, data, headers \\ []) do
      with { :ok, request } <- Request.open(unquote(name), uri),
           { :ok, request } <- Request.headers(request, headers)
      do
        request |> Request.send(data)
      else
        { :error, reason } ->
          { :error, reason }
      end
    end

    def unquote(to_string(name) <> "!" |> String.to_atom)(uri, data, headers \\ []) do
      Request.open!(unquote(name), uri) |> Request.headers!(headers) |> Request.send!(data)
    end
  end
end
