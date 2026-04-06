defmodule Xo.Games.Changes.StartCommentator do
  @moduledoc "Starts the AI commentator GenServer when a player joins a game."

  use Ash.Resource.Change
  require Logger

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.after_action(changeset, fn _changeset, game ->
      if Application.get_env(:xo, :commentator_enabled, true) do
        case DynamicSupervisor.start_child(
               Xo.Games.CommentatorSupervisor,
               {Xo.Games.Commentator, game.id}
             ) do
          {:ok, _pid} ->
            :ok

          {:error, {:already_started, _pid}} ->
            :ok

          {:error, reason} ->
            Logger.warning("Failed to start commentator for game #{game.id}: #{inspect(reason)}")
        end
      end

      {:ok, game}
    end)
  end
end
