defmodule Xo.Games.Move.Validations.ValidatePlayerTurn do
  @moduledoc """
  Validates that the actor is the next player to move.
  Reads the game from changeset context (set by DeriveFromGame change).
  """
  use Ash.Resource.Validation

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def validate(changeset, _opts, context) do
    game = changeset.context.game
    actor = context.actor

    if actor && actor.id == game.next_player_id do
      :ok
    else
      {:error, field: :player, message: "not this player's turn"}
    end
  end
end
