#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#                    Version 2, December 2004
#
#            DO WHAT THE FUCK YOU WANT TO PUBLIC LICENSE
#   TERMS AND CONDITIONS FOR COPYING, DISTRIBUTION AND MODIFICATION
#
#  0. You just DO WHAT THE FUCK YOU WANT TO.

defmodule HTTP do
  def get(uri, headers // []) do
    HTTP.Request.open(:get, uri).headers(headers).send
  end

  def head(uri, headers // []) do
    HTTP.Request.open(:head, uri).headers(headers).send
  end

  def post(uri, data, headers // []) do
    HTTP.Request.open(:post, uri).headers(headers).send(data)
  end

  def put(uri, data, headers // []) do
    HTTP.Request.open(:put, uri).headers(headers).send(data)
  end

  def delete(uri, data, headers // []) do
    HTTP.Request.open(:delete, uri).headers(headers).send(data)
  end
end
