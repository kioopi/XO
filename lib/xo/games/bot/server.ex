defmodule Xo.Games.Bot.Server do
  @moduledoc "Per-game GenServer that subscribes to game events and makes moves for a bot player."

  use GenServer
  require Logger

  alias Xo.Games

  def start_link({game_id, strategy_module, bot_user}) do
    GenServer.start_link(__MODULE__, {game_id, strategy_module, bot_user}, name: via(game_id))
  end

  def via(game_id) do
    {:via, Registry, {Xo.Games.BotRegistry, game_id}}
  end

  @impl true
  def init({game_id, strategy_module, bot_user}) do
    Phoenix.PubSub.subscribe(Xo.PubSub, "game:#{game_id}")
    delay_ms = Application.get_env(:xo, :bot_delay_ms, 1_000)

    {:ok,
     %{
       game_id: game_id,
       bot_user: bot_user,
       strategy: strategy_module,
       delay_ms: delay_ms
     }}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "make_move"}, state) do
    game =
      Games.get_by_id!(state.game_id,
        load: [:state, :next_player_id, :available_fields],
        authorize?: false
      )

    case game.state do
      :won ->
        Process.send_after(self(), :shutdown, 2_000)
        {:noreply, state}

      :draw ->
        Process.send_after(self(), :shutdown, 2_000)
        {:noreply, state}

      :active when game.next_player_id == state.bot_user.id ->
        schedule_move(state)
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: "destroy"}, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{}, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:execute_move, state) do
    try do
      game = Games.get_by_id!(state.game_id, authorize?: false)
      {:ok, field} = state.strategy.select_move(game)
      Games.make_move!(game, field, actor: state.bot_user)
    rescue
      e ->
        Logger.error(
          "Bot failed to make move in game #{state.game_id}: #{Exception.message(e)}"
        )
    end

    {:noreply, state}
  end

  @impl true
  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  defp schedule_move(state) do
    Process.send_after(self(), :execute_move, state.delay_ms)
  end
end
