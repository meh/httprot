#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule HTTP.Headers do
  @type t :: Keyword.t | record

  defrecordp :headers, __MODULE__, list: []

  def new do
    headers(list: [])
  end

  # TODO: coalesce multiple instances of same header
  def from_list(list) do
    headers(list: lc { name, value } inlist list do
      name  = name |> to_string
      key   = name |> String.downcase
      value = case key do
        "content-length" ->
          value |> binary_to_integer

        _ ->
          value |> iolist_to_binary
      end

      { key, name, value }
    end)
  end

  def contains?(headers(list: list), key) do
    List.keymember?(list, String.downcase(key), 0)
  end

  def get(headers(list: list), key, default // nil) do
    case List.keyfind(list, String.downcase(key), 0, default) do
      { _, _, value } ->
        value

      default ->
        default
    end
  end

  def put(headers(list: list), key, value) do
    headers(list: List.keystore(list, String.downcase(key), 0,
      { String.downcase(key), key, value }))
  end

  def delete(headers(list: list), key) do
    headers(list: List.keydelete(list, String.downcase(key), 0))
  end

  def push(headers(list: list), key, value) do
    headers(list: [{ String.downcase(key), key, value } | list])
  end

  def keys(headers(list: list)) do
    lc { _, key, _ } inlist list, do: key
  end

  def values(headers(list: list)) do
    lc { _, _, value } inlist list, do: value
  end

  def values(headers(list: list), key) do
    key = String.downcase(key)

    lc { ^key, _, value } inlist list, do: value
  end

  def size(headers(list: list)) do
    length list
  end

  def to_list(headers(list: list)) do
    lc { _, key, value } inlist list, do: { key, value }
  end

  def reduce(headers(list: list), acc, fun) do
    List.foldl list, acc, fn { _, key, value }, acc ->
      fun.({ key, value }, acc)
    end
  end

  def first(headers(list: [])) do
    nil
  end

  def first(headers(list: [{ _, name, value } | _])) do
    { name, value }
  end

  def next(headers(list: [])) do
    nil
  end

  def next(headers(list: [_])) do
    nil
  end

  def next(headers(list: [_ | tail])) do
    headers(list: tail)
  end
end

defimpl Data.Dictionary, for: HTTP.Headers do
  defdelegate get(self, key), to: HTTP.Headers
  defdelegate get(self, key, default), to: HTTP.Headers
  defdelegate get!(self, key), to: HTTP.Headers
  defdelegate put(self, key, value), to: HTTP.Headers
  defdelegate delete(self, key), to: HTTP.Headers
  defdelegate keys(self), to: HTTP.Headers
  defdelegate values(self), to: HTTP.Headers
end

defimpl Data.Contains, for: HTTP.Headers do
  defdelegate contains?(self, value), to: HTTP.Headers
end

defimpl Data.Emptyable, for: HTTP.Headers do
  def empty?(self) do
    HTTP.Headers.size(self) == 0
  end

  def clear(_) do
    HTTP.Headers.new
  end
end

defimpl Data.Sequence, for: HTTP.Headers do
  defdelegate first(self), to: HTTP.Headers
  defdelegate next(self), to: HTTP.Headers
end

defimpl Data.Reducible, for: HTTP.Headers do
  defdelegate reduce(self, acc, fun), to: HTTP.Headers
end

defimpl Data.Counted, for: HTTP.Headers do
  defdelegate count(self), to: HTTP.Headers, as: :size
end

defimpl Data.Listable, for: HTTP.Headers do
  defdelegate to_list(self), to: HTTP.Headers
end

defimpl Access, for: HTTP.Headers do
  defdelegate access(self, key), to: HTTP.Headers, as: :get
end

defimpl Enumerable, for: HTTP.Headers do
  use Data.Enumerable
end

defimpl String.Chars, for: HTTP.Headers do
  alias Data.Seq

  def to_string(headers) do
    [first | rest] = Seq.map headers, fn { key, value } ->
      ["\r\n", key, ": ", value]
    end

    [tl(first), rest] |> iolist_to_binary
  end
end

defimpl Inspect, for: HTTP.Headers do
  import Inspect.Algebra

  def inspect(headers, _opts) do
    concat ["#HTTP.Headers<", headers |> Data.to_list |> Kernel.inspect(_opts), ">"]
  end
end
