defmodule Xo.Games.Move.Changes.DeriveFromGame do
  @moduledoc """
  Loads the game's calculations and stashes the game in changeset context.
  Sets move_number in a before_action hook.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    game_id = Ash.Changeset.get_attribute(changeset, :game_id)

    game =
      Ash.get!(Xo.Games.Game, game_id,
        load: [:next_move_number, :next_player_id],
        authorize?: false
      )

    changeset
    |> Ash.Changeset.set_context(%{game: game})
    |> Ash.Changeset.before_action(fn changeset ->
      Ash.Changeset.force_change_attribute(
        changeset,
        :move_number,
        changeset.context.game.next_move_number
      )
    end)
  end
end
