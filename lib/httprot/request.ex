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

  alias __MODULE__
  alias HTTProt.Headers
  alias HTTProt.Response

  defstruct [:socket, :method, :uri, :headers]
  @type t :: %Request{
    socket:  nil | Socket.Stream.t,
    method:  String.t,
    uri:     URI.t,
    headers: Headers.t }

  @spec new() :: t
  @spec new(Socket.Stream.t) :: t
  def new(socket \\ nil) do
    %Request{socket: socket}
  end

  @spec open(String.t, String.t | URI.t) :: { :ok, t } | { :error, term }
  def open(method, uri) do
    open(%Request{socket: nil}, method, uri)
  end

  @spec open!(String.t, String.t | URI.t) :: t | no_return
  defbang open(method, uri)

  @spec open(t, String.t, String.t | URI.t) :: { :ok, t } | { :error, term }
  def open(%Request{socket: socket}, method, uri) do
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
      { :ok, %Request{socket: socket, method: method, uri: uri} }
    else
      { :error, reason } ->
        { :error, reason }
    end
  end

  @spec open!(t, String.t, String.t | URI.t) :: t | no_return
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

  @spec headers(t, [{ term, term }] | Headers.t) :: { :ok, t } | { :error, term }
  def headers(%Request{socket: socket} = self, headers) do
    headers = if headers |> is_list do
      headers |> Enum.into(Headers.new)
    else
      headers
    end

    case send_headers(socket, headers) do
      :ok ->
        { :ok, %Request{self | headers: headers} }

      { :error, reason } ->
        { :error, reason }
    end
  end

  @spec headers!(t, [{ term, term }] | Headers.t) :: t | no_return
  defbang headers(self, headers)

  defp send_headers(socket, headers) do
    socket |> Socket.Stream.send(Headers.to_iodata(headers))
  end

  @spec send(t) :: { :ok, Response.t } | { :error, term }
  def send(%Request{socket: socket} = self) do
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

  @spec send!(t) :: Response.t | no_return
  defbang send(request)

  @spec send(t, String.t | Map.t) :: { :ok, Response.t } | { :error, term }
  def send(%Request{socket: socket} = self, data) do
    case send_epilogue(socket, data) do
      :ok ->
        Response.new(self)

      { :error, reason } ->
        { :error, reason }
    end
  end

  @spec send!(t, String.t | Map.t) :: Response.t | no_return
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
    @moduledoc """
    Handler to stream data to the request.
    """

    use Socket.Helpers
    alias HTTProt.Request

    defstruct [:request, :socket]
    @type t :: %Stream{
      request: Request.t,
      socket:  Socket.Stream.t }

    @spec new(Request.t) :: t
    def new(request) do
      %Stream{request: request, socket: request.socket}
    end

    @spec write(t, iodata) :: :ok | { :error, term }
    def write(%Stream{socket: socket}, data) do
      socket |> Socket.Stream.send([
        :io_lib.format("~.16b", [IO.iodata_length(data)]), "\r\n",
        data, "\r\n" ])
    end

    @spec write!(t, iodata) :: :ok | no_return
    defbang write(stream, data)

    @spec close(t) :: :ok | { :error, term }
    def close(%Stream{socket: socket}) do
      socket |> Socket.Stream.send("0\r\n\r\n")
    end

    @spec close!(t) :: :ok | no_return
    defbang close(stream)
  end

  @spec stream(t) :: { :ok, Stream.t } | { :error, term }
  def stream(%Request{socket: socket} = self) do
    case send_stream(socket) do
      :ok ->
        { :ok, Stream.new(self) }

      { :error, reason } ->
        { :error, reason }
    end
  end

  @spec stream!(t) :: Streamt.t | no_return
  defbang stream(request)

  defp send_stream(socket) do
    socket |> Socket.Stream.send("Transfer-Encoding: chunked\r\n\r\n")
  end
end
