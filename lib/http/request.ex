#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule HTTP.Request do
  use Socket.Helpers

  alias HTTP.Headers
  alias HTTP.Response
  alias Data.Seq

  defrecordp :request, __MODULE__, socket: nil, method: nil, uri: nil, headers: nil

  def method(request(method: method)) do
    method
  end

  def uri(request(uri: uri)) do
    uri
  end

  def headers(request(headers: headers)) do
    headers
  end

  def for(socket // nil) do
    request(socket: socket)
  end

  def open(method, uri) do
    open(method, uri, request(socket: nil))
  end

  defbang open(method, uri)

  def open(method, uri, request(socket: socket)) do
    if uri |> is_binary do
      uri = URI.parse(uri)
    end

    connected = unless socket do
      case uri do
        URI.Info[scheme: "http", host: host, port: port] ->
          Socket.TCP.connect(host, port)

        URI.Info[scheme: "https", host: host, port: port] ->
          Socket.SSL.connect(host, port)
      end
    else
      { :ok, socket }
    end

    case connected do
      { :ok, socket } ->
        case send_prelude(socket, method, uri) do
          :ok ->
            { :ok, request(socket: socket, method: method, uri: uri) }

          { :error, _ } = error ->
            error
        end

      { :error, _ } = error ->
        error
    end
  end

  defbang open(method, uri, request)

  defp send_prelude(socket, method, uri) do
    socket |> Socket.Stream.send [
      method |> to_string |> String.upcase, " ", uri |> request_part, " HTTP/1.1\r\n",
      "Host: ", uri.authority, "\r\n"
    ]
  end

  defp request_part(URI.Info[path: path, query: nil]) do
    path || "/"
  end

  defp request_part(URI.Info[path: path, query: query]) do
    [path || "/", ??, query]
  end

  def headers(headers, request(socket: socket) = req) do
    if headers |> is_list do
      headers = Headers.from_list(headers)
    end

    case send_headers(socket, headers) do
      :ok ->
        { :ok, request(req, headers: headers) }

      { :error, _ } = error ->
        error
    end
  end

  defbang headers(headers, request)

  defp send_headers(socket, headers) do
    socket |> Socket.Stream.send Seq.map(headers, fn { name, value } ->
      [name, ": ", value, "\r\n"]
    end)
  end

  def send(request(socket: socket) = req) do
    case send_epilogue(socket) do
      :ok ->
        Response.for(req)

      { :error, _ } = error ->
        error
    end
  end

  defp send_epilogue(socket) do
    socket |> Socket.Stream.send "\r\n"
  end

  defbang send(request)

  def send(data, request(socket: socket) = req) do
    case send_epilogue(socket, data) do
      :ok ->
        Response.for(req)

      { :error, _ } = error ->
        error
    end
  end

  defbang send(data, request)

  defp send_epilogue(socket, data) when data |> is_binary do
    socket |> Socket.Stream.send [
      "Content-Length: ", data |> size |> integer_to_binary, "\r\n",
      "\r\n",
      data ]
  end

  defp send_epilogue(socket, data) do
    data = data |> Data.to_list |> URI.encode_query

    socket |> Socket.Stream.send [
      "Content-Length: ", data |> size |> integer_to_binary, "\r\n",
      "Content-Type: application/x-www-form-urlencoded", "\r\n",
      "\r\n",
      data ]
  end

  defmodule Stream do
    use Socket.Helpers

    defrecordp :stream, __MODULE__, request: nil, socket: nil

    def new(request) do
      stream(request: request, socket: elem(request, 1))
    end

    def request(stream(request: request)) do
      request
    end

    def write(data, stream(socket: socket)) do
      socket |> Socket.Stream.send([
        :io_lib.format("~.16b", [iolist_size(data)]), "\r\n",
        data, "\r\n" ])
    end

    defbang write(data, stream)

    def close(stream(socket: socket)) do
      socket |> Socket.Stream.send "0\r\n\r\n"
    end

    defbang close(stream)

    defimpl Inspect, for: Stream do
      import Inspect.Algebra

      def inspect(stream, _opts) do
        concat ["#Stream", Kernel.inspect(stream.request, _opts)]
      end
    end
  end

  def stream(request(socket: socket) = request) do
    case send_stream(socket) do
      :ok ->
        { :ok, Stream.new(request) }

      { :error, _ } = error ->
        error
    end
  end

  defbang stream(request)

  defp send_stream(socket) do
    socket |> Socket.Stream.send "Transfer-Encoding: chunked\r\n\r\n"
  end
end

defimpl Inspect, for: HTTP.Request do
  import Inspect.Algebra

  def inspect(request, _opts) do
    concat ["#HTTP.Request<",
      request.method |> to_string |> String.upcase, " ",
      request.uri |> to_string,
    ">"]
  end
end
