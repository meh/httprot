#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule HTTProt.Response do
  use Socket.Helpers

  alias __MODULE__, as: R
  alias HTTProt.Headers, as: H
  alias HTTProt.Status, as: S

  defstruct [:request, :status, :headers]

  def success?(%R{status: status}) do
    status |> S.success?
  end

  def failure?(%R{status: status}) do
    status |> S.failure?
  end

  def new(request) do
    socket = request.socket

    with :ok              <- socket |> Socket.packet(:http_bin),
         { :ok, status }  <- read_status(socket),
         { :ok, headers } <- read_headers([], socket)
    do
      { :ok, %R{request: request, status: status, headers: H.parse(headers |> Enum.reverse)} }
    else
      { :error, reason } ->
        { :error, reason }
    end
  end

  defbang new(request)

  defp read_status(socket) do
    case socket |> Socket.Stream.recv do
      { :ok, { :http_response, _, code, text } } ->
        { :ok, %S{code: code, text: text} }

      { :error, reason } ->
        { :error, reason }
    end
  end

  defp read_headers(acc, socket) do
    case socket |> Socket.Stream.recv do
      { :ok, :http_eoh } ->
        { :ok, acc }

      { :ok, { :http_header, _, name, _, value } } ->
        [{ name, value } | acc] |> read_headers(socket)

      { :error, reason } ->
        { :error, reason }
    end
  end

  defmodule Stream do
    alias __MODULE__, as: S

    defstruct [:response, :socket]

    def new(response) do
      %S{response: response, socket: response.request.socket}
    end

    def read(%S{socket: socket}) do
      with :ok           <- socket |> Socket.packet(:line),
           { :ok, line } <- socket |> Socket.Stream.recv,
           { :ok, data } <- read(socket, line |> String.rstrip |> String.to_integer(16))
      do
        { :ok, data }
      else
        { :error, reason } ->
           { :error, reason }
      end
    end

    defp read(socket, 0) do
      case socket |> Socket.Stream.recv do
        { :ok, _ } ->
          { :ok, nil }

        { :error, reason } ->
          { :error, reason }
      end
    end

    defp read(socket, size) do
      with :ok           <- socket |> Socket.packet(:raw),
           { :ok, data } <- socket |> Socket.Stream.recv(size),
           :ok           <- socket |> Socket.packet(:line),
           { :ok, _ }    <- socket |> Socket.Stream.recv
      do
        { :ok, data }
      else
        { :error, reason } ->
          { :error, reason }
      end
    end
  end

  def stream(response) do
    { :ok, Stream.new(response) }
  end

  defbang stream(response)

  def body(%R{headers: headers} = self) do
    cond do
      length = headers["Content-Length"] ->
        read_body(self, length)

      headers["Transfer-Encoding"] == "chunked" ->
        read_chunked(stream!(self))

      true ->
        read_whole(self)
    end
  end

  defbang body(response)

  defp read_body(%R{request: request}, length) do
    socket = request.socket

    with :ok           <- socket |> Socket.packet(:raw),
         { :ok, data } <- socket |> Socket.Stream.recv(length)
    do
      { :ok, data }
    else
      { :error, reason } ->
        { :error, reason }
    end
  end

  defp read_chunked(stream) do
    case read_chunked([], stream) do
      { :ok, acc } ->
        { :ok, acc |> Enum.reverse |> IO.iodata_to_binary }

      { :error, reason } ->
        { :error, reason }
    end
  end

  defp read_chunked(acc, stream) do
    case stream |> Stream.read do
      { :ok, nil } ->
        { :ok, acc }

      { :ok, chunk } ->
        [chunk | acc] |> read_chunked(stream)

      { :error, reason } ->
        { :error, reason }
    end
  end

  defp read_whole(%R{request: request}) do
    socket = request.socket

    with :ok           <- socket |> Socket.packet(:raw),
         { :ok, data } <- read_whole([], socket)
    do
      { :ok, data |> Enum.reverse |> IO.iodata_to_binary }
    else
      { :error, reason } ->
        { :error, reason }
    end
  end

  defp read_whole(data, socket) do
    case socket |> Socket.Stream.recv do
      { :ok, nil } ->
        { :ok, data }

      { :ok, chunk } ->
        [chunk | data] |> read_whole(socket)

      { :error, reason } ->
        { :error, reason }
    end
  end
end
