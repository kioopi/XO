defmodule Xo.Games.Bot.GameFragment do
  use Spark.Dsl.Fragment,
    of: Ash.Resource,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub]

  alias Xo.Games.Validations.ValidateGameState

  actions do
    update :bot_join do
      description "Have a computer player join an open game."
      require_atomic? false

      argument :strategy, :atom do
        description "The bot strategy key (e.g. :random, :strategic)."
        allow_nil? false
      end

      validate {ValidateGameState, states: [:open]}
      change Xo.Games.Bot.JoinGame
      change Xo.Games.Commentator.StartCommentator
    end
  end

  policies do
    policy action(:bot_join) do
      description "The game creator can invite a bot to join."
      forbid_unless actor_present()
      authorize_if expr(player_o_id == ^actor(:id))
    end
  end

  pub_sub do
    publish :bot_join, ["activity", :_pkey]
    publish :bot_join, [:_pkey], load: [:state, :board, :player_o, :player_x, :next_player_id]
    publish :bot_join, "lobby"
  end
end
