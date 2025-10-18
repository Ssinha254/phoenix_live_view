Application.put_env(:sample, Example.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 5002],
  server: true,
  live_view: [signing_salt: "bbbbbbbb"],
  secret_key_base: String.duplicate("b", 64)
)

Mix.install([
  {:plug_cowboy, "~> 2.5"},
  {:jason, "~> 1.0"},
  {:phoenix, "~> 1.7"},
  # Using LOCAL version of phoenix_live_view to test our changes!
  {:phoenix_live_view, path: "c:/Users/Shambhavi Sinha/Desktop/Pheonix/phoenix_live_view", override: true}
])

# Build the JS assets from the local repository to use our changes
path = "c:/Users/Shambhavi Sinha/Desktop/Pheonix/phoenix_live_view"

# Run npm and mix in a Windows-safe way. On Windows, use `cmd /c` to invoke
# shell scripts like npm.cmd and mix.bat. Also stream output to the stdio
# to avoid OS-specific :hide options that can cause :eacces on Windows.
if elem(:os.type(), 0) == :win32 do
  System.cmd("cmd", ["/c", "npm", "install"], cd: path, into: IO.stream(:stdio, :line))
  System.cmd("cmd", ["/c", "mix", "assets.build"], cd: path, into: IO.stream(:stdio, :line))
else
  System.cmd("npm", ["install"], cd: path, into: IO.stream(:stdio, :line))
  System.cmd("mix", ["assets.build"], cd: path, into: IO.stream(:stdio, :line))
end

defmodule Example.ErrorView do
  def render(template, _), do: Phoenix.Controller.status_message_from_template(template)
end

defmodule Example.HomeLive do
  use Phoenix.LiveView, layout: {__MODULE__, :live}
  import Phoenix.LiveView.JS
  alias Phoenix.LiveView.JS

  def mount(_params, _session, socket) do
    items = for i <- 1..20, do: %{id: i, title: "Item #{i}"}
    {:ok,
     socket
     |> assign(page: 1, end_of_feed: false)
     |> stream(:items, items)}
  end

  def handle_event("next-page", _, socket) do
    page = socket.assigns.page + 1
    new_items = for i <- 1..20, do: %{id: i + (page - 1) * 20, title: "Item #{i + (page - 1) * 20}"}

    # Simulate reaching the end of the feed
    end_of_feed = page >= 5

    socket =
      Enum.reduce(new_items, socket, fn item, acc ->
        stream_insert(acc, :items, item)
      end)

    {:noreply, assign(socket, page: page, end_of_feed: end_of_feed)}
  end

  def render("live.html", assigns) do
    ~H"""
    <script src="/assets/phoenix/phoenix.js"></script>
    <script src="/assets/phoenix_live_view/phoenix_live_view.js"></script>
    <script>
      let liveSocket = new window.LiveView.LiveSocket("/live", window.Phoenix.Socket)
      liveSocket.connect()
      // For debugging
      window.liveSocket = liveSocket
    </script>
    <style>
      body { font-family: sans-serif; }
      .item { padding: 1rem; border-bottom: 1px solid #eee; }
      .container { border: 1px solid #ccc; }
    </style>
    <h1 class="text-2xl font-bold mb-4">Infinite Scroll Test</h1>
    <p>Scroll down to load more items. Refresh the page after scrolling to see the issue.</p>
    <p>Page: <%= @page %>, End of Feed: <%= @end_of_feed %></p>
    <div class="container">
      <%= @inner_content %>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div
      id="articles"
      phx-update="stream"
      phx-viewport-bottom={if !@end_of_feed, do: JS.push("next-page")}
      class={if(@end_of_feed, do: "pb-10", else: "pb-[200vh]")}
      style={if(@end_of_feed, do: "padding-bottom: 2.5rem;", else: "padding-bottom: 200vh;")}
    >
      <div :for={{dom_id, item} <- @streams.items} id={dom_id} class="item">
        <%= item.title %>
      </div>
    </div>
    """
  end
end

defmodule Example.Router do
  use Phoenix.Router
  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:accepts, ["html"])
  end

  scope "/", Example do
    pipe_through(:browser)
    live("/", HomeLive, :index)
  end
end

defmodule Example.Endpoint do
  use Phoenix.Endpoint, otp_app: :sample
  socket("/live", Phoenix.LiveView.Socket)

  plug(Plug.Static, from: {:phoenix, "priv/static"}, at: "/assets/phoenix")
  plug(Plug.Static, from: {:phoenix_live_view, "priv/static"}, at: "/assets/phoenix_live_view")

  plug(Example.Router)
end

{:ok, _} = Supervisor.start_link([Example.Endpoint], strategy: :one_for_one)
Process.sleep(:infinity)
