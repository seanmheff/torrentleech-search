defmodule Torrentleech do
  use Agent

  @login_url "https://www.torrentleech.org/user/account/login/"
  @search_url "https://www.torrentleech.org/torrents/browse/autocomplete"

  def start_link do
    Agent.start_link(fn -> %{} end, name: __MODULE__)
  end

  def get(key) do
    Agent.get(__MODULE__, &Map.get(&1, key))
  end

  def put(key, value) do
    Agent.update(__MODULE__, &Map.put(&1, key, value))
  end

  def login(username, password) do
    body = {:form, [username: username, password: password]}
    headers = %{"Content-type" => "application/x-www-form-urlencoded"}
    cookies = HTTPoison.post!(@login_url, body, headers).headers
              |> Enum.filter(fn
                {"Set-Cookie", _} -> true
                _ -> false
              end)
              |> Enum.map(fn(tuple) -> elem(tuple, 1) end)
              |> Enum.map(fn(item) -> List.first(String.split(item, " ")) end)
              |> Enum.map(fn(cookie) -> String.split(cookie, "=", parts: 2) end)
              |> Enum.reduce(%{}, fn(item, acc) ->
                [key | value] = item
                Map.put(acc, key, value)
              end)
              |> Enum.map(fn{k,v} -> "#{k}=#{v}" end)
              |> Enum.join(" ")
    put("cookies", cookies)
  end

  def search(query) do
    options = [
      params: [search: query, excludeMusicCheck: "", categoryID: "28"]
    ]
    headers = %{
      "Accept" => "application/json",
      "Content-type" => "application/x-www-form-urlencoded; charset=UTF-8",
      "Cookie" => get("cookies"),
      "x-requested-with" => "XMLHttpRequest"
    }
    HTTPoison.get!(@search_url, headers, options).body
  end

  def download(url) do
    headers = %{ "Cookie" => get("cookies") }
    resp = HTTPoison.get!(url, headers)
    tmp = resp.headers
          |> List.keyfind("Content-Disposition", 0)
          |> elem(1)
          |> String.split
          |> List.last
    filename = Regex.named_captures(~r/filename=\"(?<filename>.*)\"/, tmp)["filename"]
    File.write!("/tmp/#{filename}", resp.body)
  end

  def is_logged_in? do
    get("cookies") != nil;
  end
end
