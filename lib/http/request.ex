#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule HTTP.Request do
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

  def open(method, uri, request(socket: socket)) do
    if uri |> is_binary do
      uri = URI.parse(uri)
    end

    unless socket do
      socket = case uri do
        URI.Info[scheme: "http", host: host, port: port] ->
          Socket.TCP.connect!(host, port)

        URI.Info[scheme: "https", host: host, port: port] ->
          Socket.SSL.connect!(host, port)
      end
    end

    socket.send! [method |> to_string |> String.upcase, " ", uri |> request_part, " HTTP/1.1\r\n"]
    socket.send! ["Host: ", uri.authority, "\r\n"]

    request(socket: socket, method: method, uri: uri)
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

    socket.send! Seq.map(headers, fn { name, value } ->
      [name, ": ", value, "\r\n"]
    end)

    request(req, headers: headers)
  end

  def send(request(socket: socket) = req) do
    socket.send! "\r\n"

    Response.for(req)
  end

  def send(data, request(socket: socket) = req) when is_binary(data) do
    socket.send! [
      "Content-Length: ", data |> size |> integer_to_binary, "\r\n",
      "\r\n",
      data ]

    Response.for(req)
  end

  def send(data, request(socket: socket) = req) do
    data = data |> Data.to_list |> URI.encode_query

    socket.send! [
      "Content-Length: ", data |> size |> integer_to_binary, "\r\n",
      "Content-Type: application/x-www-form-urlencoded", "\r\n",
      "\r\n",
      data ]

    Response.for(req)
  end

  defmodule Stream do
    defrecordp :stream, __MODULE__, request: nil, socket: nil

    def new(request) do
      stream(request: request, socket: elem(request, 1))
    end

    def request(stream(request: request)) do
      request
    end

    def write(data, stream(socket: socket)) do
      socket.send!([:io_lib.format("~.16b", [iolist_size(data)]), "\r\n",
                    data, "\r\n"])
    end

    def close(stream(socket: socket)) do
      socket.send! "0\r\n\r\n"
    end

    defimpl Inspect, for: Stream do
      import Inspect.Algebra

      def inspect(stream, _opts) do
        concat ["#Stream", Kernel.inspect(stream.request, _opts)]
      end
    end
  end

  def stream(request(socket: socket) = request) do
    socket.send! "Transfer-Encoding: chunked\r\n\r\n"

    Stream.new(request)
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
