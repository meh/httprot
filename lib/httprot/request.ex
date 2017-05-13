#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule HTTProt.Request do
  use Socket.Helpers
  import Kernel, except: [send: 2]

  alias __MODULE__, as: R
  alias HTTProt.Headers
  alias HTTProt.Response

  defstruct [:socket, :method, :uri, :headers]

  def new(socket \\ nil) do
    %R{socket: socket}
  end

  def open(method, uri) do
    open(%R{socket: nil}, method, uri)
  end

  defbang open(method, uri)

  def open(%R{socket: socket}, method, uri) do
    uri = if uri |> is_binary do
      URI.parse(uri)
    else
      uri
    end

    connected = if socket do
      { :ok, socket }
    else
      case uri do
        %URI{scheme: "http", host: host, port: port} ->
          Socket.TCP.connect(host, port)

        %URI{scheme: "https", host: host, port: port} ->
          Socket.SSL.connect(host, port)
      end
    end

    with { :ok, socket } <- connected,
         :ok             <- send_prelude(socket, method, uri)
    do
      { :ok, %R{socket: socket, method: method, uri: uri} }
    else
      { :error, reason } ->
        { :error, reason }
    end
  end

  defbang open(request, method, uri)

  defp send_prelude(socket, method, uri) do
    socket |> Socket.Stream.send([
      method |> to_string |> String.upcase, " ", uri |> request_part, " HTTP/1.1\r\n",
      "Host: ", uri.authority, "\r\n"
    ])
  end

  defp request_part(%URI{path: path, query: nil}) do
    path || "/"
  end

  defp request_part(%URI{path: path, query: query}) do
    [path || "/", ??, query]
  end

  def headers(%R{socket: socket} = self, headers) do
    headers = if headers |> is_list do
      headers |> Enum.into(Headers.new)
    else
      headers
    end

    case send_headers(socket, headers) do
      :ok ->
        { :ok, %R{self | headers: headers} }

      { :error, reason } ->
        { :error, reason }
    end
  end

  defbang headers(self, headers)

  defp send_headers(socket, headers) do
    socket |> Socket.Stream.send(Headers.to_iodata(headers))
  end

  def send(%R{socket: socket} = self) do
    case send_epilogue(socket) do
      :ok ->
        Response.new(self)

      { :error, reason } ->
        { :error, reason }
    end
  end

  defp send_epilogue(socket) do
    socket |> Socket.Stream.send("\r\n")
  end

  defbang send(request)

  def send(%R{socket: socket} = self, data) do
    case send_epilogue(socket, data) do
      :ok ->
        Response.new(self)

      { :error, reason } ->
        { :error, reason }
    end
  end

  defbang send(request, data)

  defp send_epilogue(socket, data) when data |> is_binary do
    socket |> Socket.Stream.send([
      "Content-Length: ", data |> byte_size |> Integer.to_string, "\r\n",
      "\r\n",
      data ])
  end

  defp send_epilogue(socket, data) do
    data = data |> URI.encode_query

    socket |> Socket.Stream.send([
      "Content-Length: ", data |> byte_size |> Integer.to_string, "\r\n",
      "Content-Type: application/x-www-form-urlencoded", "\r\n",
      "\r\n",
      data ])
  end

  defmodule Stream do
    use Socket.Helpers
    alias __MODULE__, as: S

    defstruct [:request, :socket]

    def new(request) do
      %S{request: request, socket: request.socket}
    end

    def write(%S{socket: socket}, data) do
      socket |> Socket.Stream.send([
        :io_lib.format("~.16b", [IO.iodata_length(data)]), "\r\n",
        data, "\r\n" ])
    end

    defbang write(stream, data)

    def close(%S{socket: socket}) do
      socket |> Socket.Stream.send("0\r\n\r\n")
    end

    defbang close(stream)
  end

  def stream(%R{socket: socket} = self) do
    case send_stream(socket) do
      :ok ->
        { :ok, Stream.new(self) }

      { :error, reason } ->
        { :error, reason }
    end
  end

  defbang stream(request)

  defp send_stream(socket) do
    socket |> Socket.Stream.send("Transfer-Encoding: chunked\r\n\r\n")
  end
end
