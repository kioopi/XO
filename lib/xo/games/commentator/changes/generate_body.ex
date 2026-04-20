defmodule Xo.Games.Commentator.Changes.GenerateBody do
  @moduledoc """
  Change that calls the `generate_commentary` action before the transaction
  starts and sets the result as the `:body` attribute on the changeset.

  The LLM call runs outside the DB transaction so an in-flight write
  transaction isn't held open during a potentially slow external call.
  """

  use Ash.Resource.Change

  @impl true
  def change(changeset, _opts, context) do
    Ash.Changeset.before_transaction(changeset, fn changeset ->
      game_id = Ash.Changeset.get_attribute(changeset, :game_id)
      event_description = Ash.Changeset.get_argument(changeset, :event_description)

      commentary =
        Xo.Games.generate_commentary!(game_id, event_description, actor: context.actor)

      Ash.Changeset.force_change_attribute(changeset, :body, commentary)
    end)
  end
end
