defmodule Xo.Games.Bot.Behaviour do
  @moduledoc "Defines the contract that all bot strategies must implement."

  @callback info() :: %{key: atom(), name: String.t(), description: String.t()}
  @callback bot_email() :: String.t()
  @callback select_move(game :: Ash.Resource.record()) :: {:ok, non_neg_integer()}
end
