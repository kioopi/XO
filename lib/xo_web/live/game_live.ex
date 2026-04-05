defmodule XoWeb.GameLive do
  use XoWeb, :live_view

  on_mount {XoWeb.LiveUserAuth, :live_user_optional}

  import XoWeb.GameUI
  import XoWeb.GameComponents

  alias Xo.Games
  alias XoWeb.GamePresenter

  @game_loads [
    :state,
    :board,
    :available_fields,
    :next_player_id,
    :winner_id,
    :move_count,
    :player_o,
    :player_x
  ]

  @impl true
  def mount(%{"id" => game_id}, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Xo.PubSub, "game:#{game_id}")
    end

    game = Games.get_by_id!(game_id, load: @game_loads, authorize?: false)
    socket = assign_game_data(socket, game)

    {:ok, socket}
  end

  @impl true
  def handle_event("make_move", %{"field" => field_str}, socket) do
    field = String.to_integer(field_str)
    user = socket.assigns.current_user
    game = socket.assigns.game

    try do
      Games.make_move!(game, field, actor: user)
      {:noreply, socket}
    rescue
      _e in [Ash.Error.Invalid, Ash.Error.Forbidden] ->
        {:noreply, put_flash(socket, :error, "Could not make that move")}
    end
  end

  def handle_event("join_game", _params, socket) do
    user = socket.assigns.current_user
    game = socket.assigns.game

    try do
      Games.join!(game, actor: user)
      {:noreply, socket}
    rescue
      _e in [Ash.Error.Invalid, Ash.Error.Forbidden] ->
        {:noreply, put_flash(socket, :error, "Could not join game")}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{}, socket) do
    game = Games.get_by_id!(socket.assigns.game.id, load: @game_loads, authorize?: false)
    {:noreply, assign_game_data(socket, game)}
  end

  defp assign_game_data(socket, game) do
    user = socket.assigns.current_user
    role = GamePresenter.role(game, user)

    socket
    |> assign(:game, game)
    |> assign(:role, role)
    |> assign(:clickable_fields, GamePresenter.clickable_fields(game, user))
    |> assign(:status_text, GamePresenter.status_text(game, user))
    |> assign(:page_title, "Game ##{game.id}")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title={"Game ##{@game.id}"}>
      <:actions>
        <.link navigate={~p"/"} class="btn btn-ghost btn-sm">
          ← Lobby
        </.link>
      </:actions>
    </.page_header>

    <.game_status_banner status_text={@status_text} />

    <div class="flex flex-col md:flex-row gap-6">
      <div class="flex-1">
        <.board board={@game.board} clickable_fields={@clickable_fields} />
      </div>
      <div class="w-full md:w-64 flex flex-col gap-4">
        <.game_header game={@game} role={@role} />
        <.players_panel game={@game} role={@role} current_user={@current_user} />
        <.action_bar game={@game} role={@role} current_user={@current_user} />
      </div>
    </div>
    """
  end
end
