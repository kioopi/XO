defmodule Xo.Games.Commentator.Server do
  @moduledoc "Per-game GenServer that subscribes to game events and posts AI commentary to chat."

  use GenServer
  require Logger

  alias Xo.Games

  def start_link(game_id) do
    GenServer.start_link(__MODULE__, game_id, name: via(game_id))
  end

  def via(game_id) do
    {:via, Registry, {Xo.Games.CommentatorRegistry, game_id}}
  end

  @impl true
  def init(game_id) do
    Phoenix.PubSub.subscribe(Xo.PubSub, "game:#{game_id}")
    {:ok, %{game_id: game_id, bot: nil}, {:continue, :greet}}
  end

  @impl true
  def handle_continue(:greet, state) do
    bot = Xo.Games.Commentator.Bot.user()

    try do
      generate_and_post(
        state.game_id,
        bot,
        "Both players have joined. The game is about to begin"
      )
    rescue
      e -> Logger.error("Commentator greeting failed: #{Exception.message(e)}")
    end

    {:noreply, %{state | bot: bot}}
  end

  @impl true
  def handle_info(%Phoenix.Socket.Broadcast{event: event}, %{bot: nil} = state) do
    # Bot not yet initialized, ignore events
    Logger.debug("Commentator for game #{state.game_id} received event before init: #{event}")
    {:noreply, state}
  end

  def handle_info(%Phoenix.Socket.Broadcast{event: event} = broadcast, state) do
    case classify_event(event, broadcast.payload) do
      {:comment, description} ->
        generate_and_post(state.game_id, state.bot, description)
        {:noreply, state}

      :game_over ->
        generate_and_post(state.game_id, state.bot, "The game has ended! Summarize the result.")
        # Allow time for the async commentary task to complete before stopping
        Process.send_after(self(), :shutdown, 5_000)
        {:noreply, state}

      :abandoned ->
        {:stop, :normal, state}

      :ignore ->
        {:noreply, state}
    end
  end

  def handle_info(:shutdown, state) do
    {:stop, :normal, state}
  end

  defp classify_event("make_move", %{data: game}) do
    case game.state do
      :won -> :game_over
      :draw -> :game_over
      :active -> {:comment, "A move was just made. The game is still active."}
      _ -> :ignore
    end
  end

  defp classify_event("destroy", _payload) do
    :abandoned
  end

  defp classify_event(_event, _payload), do: :ignore

  defp generate_and_post(game_id, bot, event_description) do
    Task.Supervisor.start_child(Xo.Games.CommentatorTaskSupervisor, fn ->
      try do
        commentary = Games.generate_commentary!(game_id, event_description, actor: bot)
        post_message(game_id, bot, commentary)
      rescue
        e ->
          Logger.error("Commentator failed: #{Exception.message(e)}")
      end
    end)
  end

  defp post_message(game_id, bot, body) do
    Games.create_message!(body, %{game_id: game_id}, actor: bot)
  end
end
