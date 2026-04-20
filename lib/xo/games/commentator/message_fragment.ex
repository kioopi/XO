defmodule Xo.Games.Commentator.MessageFragment do
  @moduledoc """
  Extends `Xo.Games.Message` with the `:post_commentary` create action, which
  generates LLM commentary for a game event and persists it as a chat message
  authored by the commentator bot.
  """

  alias Xo.Games.Commentator.Changes

  use Spark.Dsl.Fragment, of: Ash.Resource

  actions do
    create :post_commentary do
      description """
      Generate LLM commentary for a game event and persist it as a chat message
      authored by the commentator bot.
      """

      accept [:game_id]

      argument :event_description, :string do
        allow_nil? false
        description "What just happened in the game."
      end

      change Changes.GenerateBody
      change Changes.RelateBotUser
    end
  end
end
