defmodule Xo.Games.Bot.JoinGame do
  @moduledoc "Ash change that joins a bot as player_x and starts the Bot.Server."

  use Ash.Resource.Change
  require Logger

  alias Xo.Games.Bot.{BotUser, Strategy}

  @impl true
  def change(changeset, _opts, _context) do
    strategy_key = Ash.Changeset.get_argument(changeset, :strategy)
    strategy_module = Strategy.module_for!(strategy_key)
    bot_user = BotUser.user(strategy_module)

    changeset
    |> Ash.Changeset.force_change_attribute(:player_x_id, bot_user.id)
    |> Ash.Changeset.after_action(fn _changeset, game ->
      if Application.get_env(:xo, :bot_enabled, true) do
        case DynamicSupervisor.start_child(
               Xo.Games.BotSupervisor,
               {Xo.Games.Bot.Server, {game.id, strategy_module, bot_user}}
             ) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok

          {:error, reason} ->
            Logger.warning("Failed to start bot for game #{game.id}: #{inspect(reason)}")
        end
      end

      {:ok, game}
    end)
  end
end
