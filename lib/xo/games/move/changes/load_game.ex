defmodule Xo.Games.Move.Changes.LoadGame do
  @moduledoc """
  Loads the game with calculations and stashes it in changeset context.
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

    Ash.Changeset.set_context(changeset, %{game: game})
  end
end
