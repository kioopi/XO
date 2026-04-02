defmodule Xo.Games.Changes.CreateMove do
  @moduledoc """
  Change for Game.make_move that creates a Move record via manage_relationship.
  """
  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, _context) do
    field = Ash.Changeset.get_argument(changeset, :field)
    game_id = changeset.data.id

    Ash.Changeset.manage_relationship(changeset, :moves, [%{field: field, game_id: game_id}],
      type: :create
    )
  end
end
