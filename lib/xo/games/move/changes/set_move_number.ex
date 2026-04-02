defmodule Xo.Games.Move.Changes.SetMoveNumber do
  @moduledoc """
  Sets move_number from the game's next_move_number calculation.
  Runs in a before_action hook inside the transaction.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    Ash.Changeset.before_action(changeset, fn changeset ->
      Ash.Changeset.force_change_attribute(
        changeset,
        :move_number,
        changeset.context.game.next_move_number
      )
    end)
  end
end
