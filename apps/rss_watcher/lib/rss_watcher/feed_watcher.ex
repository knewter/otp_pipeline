defmodule RssWatcher.FeedWatcher do
  use GenServer

  ## Public API
  def start_link(url) do
    GenServer.start_link(__MODULE__, [url], [])
  end


  ## Server API
  def init(url) do
    send(self, :fetch)
    {:ok, {url, Timex.now}}
  end

  def handle_info(:fetch, state={url, last_time}) do
    :timer.send_after(1_000, :fetch)
    with {:ok, feed} <- fetch_feed(url),
         {:ok, entries} <- feed.entries |> parse_times,
         {:ok, new=[newest|_]} <- entries |> filter_entries(last_time) do
      for entry <- new do
        FeedEntryHandler.Handler.handle(entry)
      end
      {:noreply, {url, newest.updated}}
    else
      _ ->
        {:noreply, state}
    end
  end

  defp fetch_feed(url) do
    {:ok, %HTTPoison.Response{body: body}} = HTTPoison.get(url)
    {:ok, feed, _} = FeederEx.parse(body)
    {:ok, feed}
  end

  defp parse_times(entries) do
    parsed =
      for entry <- entries do
        %FeederEx.Entry{ entry | updated: Timex.parse!(entry.updated, "{ISO:Extended}") }
      end
    {:ok, parsed}
  end

  defp filter_entries(entries, last_time) do
    filtered =
      for entry <- entries, Timex.after?(entry.updated, last_time) do
        entry
      end
    {:ok, filtered}
  end
end
