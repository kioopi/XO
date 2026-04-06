defmodule XoWeb.LobbyLive do
  use XoWeb, :live_view

  on_mount {XoWeb.LiveUserAuth, :live_user_optional}

  import XoWeb.GameUI
  import XoWeb.LobbyComponents

  alias Xo.Games

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xo.PubSub, "game:lobby")
    end

    socket =
      socket
      |> assign(:page_title, "Lobby")
      |> load_games()

    {:ok, socket}
  end

  @impl true
  def handle_event("create_game", _params, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, put_flash(socket, :error, "You must be signed in to create a game")}

      user ->
        game = Games.create_game!(actor: user)
        {:noreply, push_navigate(socket, to: ~p"/games/#{game.id}")}
    end
  end

  def handle_event("join_game", %{"game-id" => game_id}, socket) do
    case socket.assigns.current_user do
      nil ->
        {:noreply, put_flash(socket, :error, "You must be signed in to join a game")}

      user ->
        game = Games.get_by_id!(game_id)
        Games.join!(game, actor: user)
        {:noreply, push_navigate(socket, to: ~p"/games/#{game_id}")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{}, socket) do
    {:noreply, load_games(socket)}
  end

  defp load_games(socket) do
    actor = socket.assigns[:current_user]

    open_games =
      Games.list_open_games!(
        load: [:player_o, :state, :move_count],
        actor: actor,
        authorize?: false
      )

    active_games =
      Games.list_active_games!(
        load: [:player_o, :player_x, :state, :move_count, :next_player_id],
        actor: actor,
        authorize?: false
      )

    socket
    |> assign(:open_games, open_games)
    |> assign(:active_games, active_games)
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title="XO">
      <:actions>
        <button :if={@current_user} phx-click="create_game" class="btn btn-primary btn-sm">
          New Game
        </button>
      </:actions>
    </.page_header>

    <.player_status current_user={@current_user} />

    <.section title="Open Games">
      <%= if @open_games == [] do %>
        <.empty_state message="No open games yet" />
      <% else %>
        <.games_list games={@open_games} current_user={@current_user} variant={:open} />
      <% end %>
    </.section>

    <.section title="Active Games">
      <%= if @active_games == [] do %>
        <.empty_state message="No active games" />
      <% else %>
        <.games_list games={@active_games} current_user={@current_user} variant={:active} />
      <% end %>
    </.section>
    """
  end
end
