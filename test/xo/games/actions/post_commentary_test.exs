defmodule Xo.Games.Actions.PostCommentaryTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User, only: [user: 0]
  import Xo.Generators.Game, only: [game: 1]
  import Ash.Generator, only: [generate: 1]

  alias Xo.Games
  alias Xo.Games.Message

  setup do
    player_o = generate(user())
    player_x = generate(user())
    game = generate(game(actor: player_o))
    game = Ash.update!(game, %{}, action: :join, actor: player_x, authorize?: true)

    %{game: game, player_o: player_o, player_x: player_x}
  end

  describe "post_commentary action" do
    test "requires an actor", %{game: game} do
      assert {:error, %Ash.Error.Forbidden{}} =
               Ash.create(
                 Message,
                 %{game_id: game.id, event_description: "A move was made."},
                 action: :post_commentary,
                 authorize?: true
               )
    end

    test "fails on non-existent game_id", %{player_o: actor} do
      assert_raise Ash.Error.Invalid, fn ->
        Games.post_commentary!(-1, "A move was made.", actor: actor)
      end
    end

    test "no message is persisted when the LLM call fails", %{game: game, player_o: actor} do
      count_before = Ash.count!(Message, authorize?: false)

      # The LLM has no API key in the test env, so generate_commentary raises.
      # A before_transaction raise must abort the create cleanly.
      assert_raise Ash.Error.Unknown, fn ->
        Games.post_commentary!(game.id, "A move was made.", actor: actor)
      end

      count_after = Ash.count!(Message, authorize?: false)
      assert count_after == count_before
    end

    test "delegates body generation to generate_commentary", %{game: game, player_o: actor} do
      # The LLM fails, but the bread crumbs in the error confirm the body-generation
      # path ran through generate_commentary → generate_commentary_with_context.
      error =
        assert_raise Ash.Error.Unknown, fn ->
          Games.post_commentary!(game.id, "A move was made.", actor: actor)
        end

      assert Exception.message(error) =~ "generate_commentary_with_context"
    end
  end

  describe "RelateBotUser change" do
    test "unit: pins :user relationship to the commentator bot" do
      bot = Xo.Games.Commentator.Bot.user()

      changeset =
        Message
        |> Ash.Changeset.new()
        |> Ash.Changeset.for_create(:post_commentary, %{game_id: 1, event_description: "x"},
          authorize?: false
        )

      # After the change pipeline runs, the :user relationship should be managed
      # and target the bot regardless of who the actor is.
      assert %Ash.Changeset{} = changeset
      assert Map.has_key?(changeset.relationships, :user)
      [{[^bot], _opts}] = changeset.relationships.user
    end
  end
end
