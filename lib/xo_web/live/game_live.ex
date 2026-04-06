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
      Phoenix.PubSub.subscribe(Xo.PubSub, "game:chat:#{game_id}")
    end

    game = Games.get_by_id!(game_id, load: @game_loads, authorize?: false)
    messages = Games.list_messages!(game_id, load: [:user], authorize?: false)

    socket =
      socket
      |> assign_game_data(game)
      |> assign(:messages, messages)
      |> assign(:message_form, new_message_form(game.id, socket.assigns.current_user))

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

  def handle_event("validate_message", %{"form" => params}, socket) do
    form = AshPhoenix.Form.validate(socket.assigns.message_form, params)
    {:noreply, assign(socket, :message_form, to_form(form))}
  end

  def handle_event("send_message", %{"form" => params}, socket) do
    case AshPhoenix.Form.submit(socket.assigns.message_form, params: params) do
      {:ok, _message} ->
        form = new_message_form(socket.assigns.game.id, socket.assigns.current_user)
        {:noreply, assign(socket, :message_form, form)}

      {:error, form} ->
        {:noreply, assign(socket, :message_form, to_form(form))}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{topic: "game:chat:" <> _} = broadcast, socket) do
    message = broadcast.payload.data
    {:noreply, assign(socket, :messages, socket.assigns.messages ++ [message])}
  end

  def handle_info(%Phoenix.Socket.Broadcast{}, socket) do
    game = Games.get_by_id!(socket.assigns.game.id, load: @game_loads, authorize?: false)
    {:noreply, assign_game_data(socket, game)}
  end

  defp new_message_form(game_id, user) do
    Games.form_to_create_message(
      actor: user,
      prepare_source: fn changeset ->
        Ash.Changeset.force_change_attribute(changeset, :game_id, game_id)
      end
    )
    |> to_form()
  end

  defp assign_game_data(socket, game) do
    user = socket.assigns.current_user
    role = GamePresenter.role(game, user)

    socket
    |> assign(:game, game)
    |> assign(:role, role)
    |> assign(:clickable_fields, GamePresenter.clickable_fields(game, user))
    |> assign(:status_text, GamePresenter.status_text(game, user))
    |> assign(:current_mark, GamePresenter.your_mark(game, user))
    |> assign(:winning_cells, GamePresenter.winning_cells(game))
    |> assign(:page_title, "Game ##{game.id}")
  end

  @impl true
  def render(assigns) do
    ~H"""
    <.page_header title={"Game ##{@game.id}"}>
      <:actions>
        <.link navigate={~p"/"} class="btn btn-ghost btn-sm rounded-xl">
          ← Lobby
        </.link>
      </:actions>
    </.page_header>

    <div class="flex flex-col lg:flex-row gap-8">
      <div class="flex-1 flex flex-col items-center gap-6">
        <.game_status_banner status_text={@status_text} game_state={@game.state} />
        <.board
          board={@game.board}
          clickable_fields={@clickable_fields}
          current_mark={@current_mark}
          winning_cells={@winning_cells}
        />
      </div>
      <div class="w-full lg:w-72 flex flex-col gap-4">
        <.game_header game={@game} role={@role} />
        <.players_panel game={@game} role={@role} current_user={@current_user} />
        <.action_bar game={@game} role={@role} current_user={@current_user} />
        <.chat_panel messages={@messages} message_form={@message_form} current_user={@current_user} />
      </div>
    </div>
    """
  end
end
