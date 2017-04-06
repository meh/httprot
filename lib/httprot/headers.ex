#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule HTTProt.Headers do
  defstruct inner: %{}

  alias __MODULE__, as: T
  alias HTTProt.Cookie
  alias Data.Protocol, as: D

  def new do
    %T{}
  end

  def parse(string) when string |> is_binary do
    for line <- string |> String.split(~r/\r?\n/), line != "" do
      [name, value] = line |> String.split(~r/\s*:\s*/, parts: 2)

      { name, value }
    end |> parse
  end

  def parse(enum) do
    %T{inner: Enum.reduce(enum, %{}, fn { name, value }, headers ->
      name = to_string(name)
      key  = String.downcase(name)

      Map.update headers, key, { name, from_string(key, value) }, fn
        { name, old } when old |> is_list ->
          { name, old ++ from_string(key, value) }

        { name, old } ->
          case from_string(key, value) do
            value when value |> is_list ->
              { name, [old | value] }

            value ->
              { name, value }
          end
      end
    end)}
  end

  def fetch(self, name) do
    name = name |> to_string
    key  = String.downcase(name)

    case Map.fetch(self.inner, key) do
      { :ok, { _, value } } ->
        { :ok, value }

      :error ->
        :error
    end
  end

  def put(self, name, value) do
    name  = name |> to_string
    key   = String.downcase(name)
    value = if value |> is_binary do
      from_string(key, value)
    else
      value
    end

    %T{self | inner: Map.put(self.inner, key, { name, value })}
  end

  def delete(self, name) do
    name = name |> to_string
    key  = String.downcase(name)

    %T{self | inner: Map.delete(self.inner, key)}
  end

  def size(self) do
    self.inner |> Map.size
  end

  def to_iodata(self) do
    for { name, value } <- self, into: [] do
      [name, ": ", to_string(String.downcase(name), value), "\r\n"]
    end
  end

  defp to_string("accept", value) when value |> is_list do
    for { name, quality } <- value do
      if quality == 1.0 do
        name
      else
        "#{name};q=#{quality}"
      end
    end |> Enum.join(",")
  end

  defp to_string("content-length", value) do
    value |> to_string
  end

  defp to_string("cookie", value) do
    Enum.map(value, &URI.encode_query([{ &1.name, &1.value }]))
      |> Enum.join("; ")
  end

  defp to_string(_, value) when value |> is_list do
    Enum.join value, ", "
  end

  defp to_string(_, value) when value |> is_binary do
    value
  end

  defp from_string("accept", value) do
    for part <- value |> String.split(~r/\s*,\s*/) do
      case part |> String.split(~r/\s*;\s*/) do
        [type] ->
          { type, 1.0 }

        [type, "q=" <> quality] ->
          { type, Float.parse(quality) |> elem(0) }
      end
    end
  end

  defp from_string("cache-control", value) do
    value |> String.split(~r/\s*,\s*/)
  end

  defp from_string("content-length", value) do
    String.to_integer(value)
  end

  defp from_string("cookie", value) do
    for cookie <- value |> String.split(~r/\s*;\s*/) do
      case String.split(cookie, ~r/=/, parts: 2) do
        [name, value] -> %Cookie{name: name, value: value}
        _ -> %Cookie{name: "failed", value: "failed"}
      end
    end
  end

  defp from_string(_, value) do
    value
  end

  defimpl String.Chars do
    def to_string(self) do
      T.to_iodata(self) |> IO.iodata_to_binary
    end
  end

  defimpl D.Dictionary do
    defdelegate fetch(self, key), to: T
    defdelegate put(self, key, value), to: T
    defdelegate delete(self, key), to: T

    def keys(%T{inner: inner}) do
      Map.keys(inner)
    end

    def values(%T{inner: inner}) do
      Map.values(inner) |> Enum.map(&elem(&1, 1))
    end
  end

  defimpl D.Count do
    defdelegate count(self), to: T, as: :size
  end

  defimpl D.Empty do
    def empty?(self) do
      T.size(self) == 0
    end

    def clear(_) do
      T.new()
    end
  end

  defimpl D.Reduce do
    def reduce(%T{inner: inner}, acc, fun) do
      Data.reduce(inner, acc, fn { _, { name, value } }, acc ->
        fun.({ name, value }, acc)
      end)
    end
  end

  defimpl D.Contains do
    def contains?(%T{inner: inner}, name) do
      name = to_string(name)
      key  = String.downcase(name)

      match? { :ok, _ }, Map.fetch(inner, key)
    end
  end

  defimpl D.Into do
    def into(self, { key, value }) do
      self |> T.put(key, value)
    end
  end

  defimpl Enumerable do
    use Data.Enumerable
  end

  defimpl Collectable do
    use Data.Collectable
  end

  defimpl Inspect do
    import Inspect.Algebra

    def inspect(self, opts) do
      concat ["#Headers<", to_doc(Data.list(self), opts), ">"]
    end
  end
end
