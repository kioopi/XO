defmodule Xo.Games.Bot.StrategyTest do
  use Xo.DataCase, async: true

  alias Xo.Games

  describe "list_strategies" do
    test "returns all available strategies" do
      strategies = Games.list_strategies!()

      assert length(strategies) == 2
      keys = Enum.map(strategies, & &1.key) |> Enum.sort()
      assert keys == [:random, :strategic]
    end

    test "each strategy has name and description" do
      strategies = Games.list_strategies!()

      for strategy <- strategies do
        assert is_binary(strategy.name)
        assert is_binary(strategy.description)
      end
    end
  end

  describe "module_for!/1" do
    test "returns module for :random" do
      assert Xo.Games.Bot.Strategy.module_for!(:random) == Xo.Games.Bot.Strategies.Random
    end

    test "returns module for :strategic" do
      assert Xo.Games.Bot.Strategy.module_for!(:strategic) == Xo.Games.Bot.Strategies.Strategic
    end

    test "raises for unknown strategy" do
      assert_raise KeyError, fn ->
        Xo.Games.Bot.Strategy.module_for!(:nonexistent)
      end
    end
  end
end
