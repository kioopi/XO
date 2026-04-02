defmodule Xo.Generators.Move do
  use Ash.Generator

  alias Xo.Games.Move

  def move(overrides \\ []) do
    {game, overrides} =
      Keyword.pop_lazy(overrides, :game, fn ->
        player_o = generate(Xo.Generators.User.user())
        game = generate(Xo.Generators.Game.game(actor: player_o))
        player_x = generate(Xo.Generators.User.user())
        Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)
      end)

    game = Ash.load!(game, [:next_player_id], authorize?: false)

    {actor, overrides} =
      Keyword.pop_lazy(overrides, :actor, fn ->
        Ash.get!(Xo.Accounts.User, game.next_player_id, authorize?: false)
      end)

    overrides =
      Keyword.put_new(overrides, :game_id, game.id)

    changeset_generator(
      Move,
      :create,
      actor: actor,
      overrides: overrides
    )
  end
end
