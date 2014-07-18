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
    socket |> Socket.packet! :http_bin

    case read_status(socket) do
      { :ok, status } ->
        case read_headers([], socket) do
          { :ok, headers } ->
            { :ok, %R{request: request, status: status, headers: H.parse(headers |> Enum.reverse)} }

          { :error, _ } = error ->
            error
        end

      { :error, _ } = error ->
        error
    end
  end

  defbang new(request)

  defp read_status(socket) do
    case socket |> Socket.Stream.recv do
      { :ok, { :http_response, _, code, text } } ->
        { :ok, %S{code: code, text: text} }

      { :error, _ } = error ->
        error
    end
  end

  defp read_headers(acc, socket) do
    case socket |> Socket.Stream.recv do
      { :ok, :http_eoh } ->
        { :ok, acc }

      { :ok, { :http_header, _, name, _, value } } ->
        [{ name, value } | acc] |> read_headers(socket)

      { :error, _ } = error ->
        error
    end
  end

  defmodule Stream do
    alias __MODULE__, as: S

    defstruct [:response, :socket]

    def new(response) do
      %S{response: response, socket: response.request.socket}
    end

    def read(%S{socket: socket}) do
      socket |> Socket.packet! :line

      case socket |> Socket.Stream.recv do
        { :ok, line } ->
          case line |> String.rstrip |> String.to_integer(16) do
            0 ->
              case socket |> Socket.Stream.recv do
                { :ok, _ } ->
                  { :ok, nil }

                { :error, _ } = error ->
                  error
              end

            size ->
              socket |> Socket.packet! :raw

              case socket |> Socket.Stream.recv(size) do
                { :ok, data } ->
                  socket |> Socket.packet! :line

                  case socket |> Socket.Stream.recv do
                    { :ok, _ } ->
                      { :ok, data }

                    { :error, _ } = error ->
                      error
                  end

                { :error, _ } = error ->
                  error
              end
          end

        { :error, _ } = error ->
          error
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
    end
  end

  defbang body(response)

  defp read_body(%R{request: request}, length) do
    socket = request.socket

    socket |> Socket.packet! :raw
    socket |> Socket.Stream.recv(length)
  end

  defp read_chunked(stream) do
    case read_chunked([], stream) do
      { :ok, acc } ->
        { :ok, acc |> Enum.reverse |> IO.iodata_to_binary }

      { :error, _ } = error ->
        error
    end
  end

  defp read_chunked(acc, stream) do
    case stream |> Stream.read do
      { :ok, nil } ->
        { :ok, acc }

      { :ok, chunk } ->
        [chunk | acc] |> read_chunked(stream)

      { :error, _ } = error ->
        error
    end
  end
end

