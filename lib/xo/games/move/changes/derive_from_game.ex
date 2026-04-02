defmodule Xo.Games.Move.Changes.DeriveFromGame do
  @moduledoc """
  Loads the game's calculations and sets move_number on the changeset.
  Stashes the loaded game in changeset context for use by validations.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      game_id = Ash.Changeset.get_attribute(changeset, :game_id)

      game =
        Ash.get!(Xo.Games.Game, game_id,
          load: [:next_move_number, :next_player_id],
          authorize?: false
        )

      changeset
      |> Ash.Changeset.force_change_attribute(:move_number, game.next_move_number)
      |> Ash.Changeset.set_context(%{game: game})
    end)
  end
end
