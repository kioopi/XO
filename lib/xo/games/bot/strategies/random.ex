defmodule Xo.Games.Bot.Strategies.Random do
  @moduledoc "Bot strategy that selects a random available field."

  @behaviour Xo.Games.Bot.Behaviour

  @impl true
  def info do
    %{key: :random, name: "Random Bot", description: "Picks a random available field."}
  end

  @impl true
  def bot_email, do: "random-bot@xo.bot"

  @impl true
  def select_move(game) do
    game = Ash.load!(game, [:available_fields])
    {:ok, Enum.random(game.available_fields)}
  end
end
