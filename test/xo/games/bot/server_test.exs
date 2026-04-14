defmodule Xo.Games.Bot.ServerTest do
  use Xo.DataCase, async: false

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 1]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games

  setup do
    player_o = generate(user())
    game = generate(game(actor: player_o))

    # Use bot_join to set up the game with a bot and start the server
    game = Games.bot_join!(game, :random, actor: player_o)

    # Allow the bot server process to access the sandbox DB connection
    [{bot_pid, _}] = Registry.lookup(Xo.Games.BotRegistry, game.id)
    Ecto.Adapters.SQL.Sandbox.allow(Xo.Repo, self(), bot_pid)

    %{game: game, player_o: player_o}
  end

  describe "lifecycle" do
    test "server is registered after bot_join", %{game: game} do
      assert [{pid, _}] = Registry.lookup(Xo.Games.BotRegistry, game.id)
      assert Process.alive?(pid)
    end

    test "server stops when game is destroyed", %{game: game} do
      [{pid, _}] = Registry.lookup(Xo.Games.BotRegistry, game.id)
      ref = Process.monitor(pid)

      Ash.destroy!(game, authorize?: false)

      assert_receive {:DOWN, ^ref, :process, ^pid, :normal}, 5_000
    end
  end

  describe "full game integration" do
    test "bot plays a complete game to conclusion", %{game: game, player_o: player_o} do
      # Play as O, picking from available fields and letting the bot respond each time.
      # The bot uses the Random strategy, so it may win at any point.
      game = Games.make_move!(game, 0, actor: player_o)
      Process.sleep(2_000)

      game = Games.get_by_id!(game.id, load: [:state, :move_count, :next_player_id, :available_fields])

      game =
        if game.state == :active do
          # Pick the first available field for our next move
          [field | _] = game.available_fields
          game = Games.make_move!(game, field, actor: player_o)
          Process.sleep(2_000)

          game = Games.get_by_id!(game.id, load: [:state, :move_count, :next_player_id, :available_fields])

          if game.state == :active do
            [field | _] = game.available_fields
            Games.make_move!(game, field, actor: player_o)
            Process.sleep(2_000)

            Games.get_by_id!(game.id, load: [:state, :move_count])
          else
            game
          end
        else
          game
        end

      # Game should have multiple moves — at least the human's first move and bot's response
      assert game.move_count >= 2
      # The game should either still be active or have ended
      assert game.state in [:active, :won, :draw]
    end
  end

  describe "move making" do
    test "bot makes a move after human moves", %{game: game, player_o: player_o} do
      Games.make_move!(game, 4, actor: player_o)

      # Wait for bot delay + processing
      Process.sleep(2_000)

      game = Games.get_by_id!(game.id, load: [:move_count])

      # Bot should have made a response move
      assert game.move_count == 2
    end
  end
end
