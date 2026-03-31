defmodule Xo.Generators.Game do
  use Ash.Generator

  alias Xo.Games.Game

  def game(overrides \\ []) do
    {actor, overrides} =
      Keyword.pop_lazy(overrides, :actor, fn ->
        generate(Xo.Generators.User.user())
      end)

    changeset_generator(
      Game,
      :create,
      actor: actor,
      authorize?: true,
      overrides: overrides
    )
  end
end
