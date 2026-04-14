defmodule Xo.Games.Bot.DomainFragment do
  use Spark.Dsl.Fragment,
    of: Ash.Domain

  resources do
    resource Xo.Games.Bot.Strategy do
      define :list_strategies, action: :read
    end
  end
end
