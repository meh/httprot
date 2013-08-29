#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule HTTP.Response do
  alias HTTP.Headers, as: H
  alias Data.Dict, as: D

  defrecordp :response, __MODULE__, request: nil, status: nil, headers: nil

  defrecord Status, code: nil, text: nil do
    def success?(Status[code: code]) when code >= 200 and code < 300 or code == 304 do
      true
    end

    def success?(_) do
      false
    end

    def failure?(self) do
      not success?(self)
    end
  end

  def request(response(request: request)) do
    request
  end

  def status(response(status: status)) do
    status
  end

  def success?(response(status: status)) do
    status.success?
  end

  def failure?(response(status: status)) do
    status.failure?
  end

  def headers(response(headers: headers)) do
    headers
  end

  def for(request) do
    socket = elem(request, 1)
    socket.packet!(:http_bin)

    status  = read_status(socket)
    headers = read_headers([], socket)

    response(request: request, status: status, headers: H.from_list(headers))
  end

  defp read_status(socket) do
    case socket.recv! do
      { :http_response, _, code, text } ->
        Status[code: code, text: text]
    end
  end

  defp read_headers(acc, socket) do
    case socket.recv! do
      :http_eoh ->
        acc

      { :http_header, _, name, _, value } ->
        [{ name, value } | acc] |> read_headers(socket)
    end
  end

  defmodule Stream do
    defrecordp :stream, __MODULE__, response: nil, socket: nil

    def new(response) do
      stream(response: response, socket: elem(response.request, 1))
    end

    def response(stream(response: response)) do
      response
    end

    def read(stream(socket: socket)) do
      socket.packet! :line

      case socket.recv! |> String.rstrip |> binary_to_integer(16) do
        0 ->
          socket.recv!
          nil

        size ->
          socket.packet! :raw
          res = socket.recv!(size)
          socket.packet! :line
          socket.recv!
          res
      end
    end

    defimpl Inspect, for: Stream do
      import Inspect.Algebra

      def inspect(stream, _opts) do
        concat ["#Stream", Kernel.inspect(stream.response, _opts)]
      end
    end
  end

  def stream(response) do
    Stream.new(response)
  end

  def body(response(headers: headers) = res) do
    cond do
      length = D.get(headers, "Content-Length") ->
        read_body(res, length)

      D.get(headers, "Transfer-Encoding") == "chunked" ->
        read_chunked(stream(res))
    end
  end

  defp read_body(response(request: req), length) do
    socket = elem(req, 1)

    socket.packet! :raw
    socket.recv!(length)
  end

  defp read_chunked(stream) do
    read_chunked([], stream) |> Enum.reverse |> iolist_to_binary
  end

  defp read_chunked(acc, stream) do
    case stream.read do
      nil ->
        acc

      chunk ->
        [chunk | acc] |> read_chunked(stream)
    end
  end
end

defimpl Inspect, for: HTTP.Response do
  import Inspect.Algebra

  def inspect(response, _opts) do
    concat ["#HTTP.Response<",
      response.request.method |> to_string |> String.upcase, " ",
      response.request.uri |> to_string, ": ",
      response.status.code |> to_string, " ", response.status.text,
    ">"]
  end
end
