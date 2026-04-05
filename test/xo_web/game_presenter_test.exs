defmodule XOWeb.GamePresenterTest do
  use ExUnit.Case, async: true

  alias XOWeb.GamePresenter

  # Minimal structs for testing — no database needed
  defp game(attrs \\ %{}) do
    Map.merge(
      %{
        player_o_id: 1,
        player_x_id: 2,
        state: :active,
        next_player_id: 1,
        available_fields: [0, 1, 2, 3, 4, 5, 6, 7, 8],
        winner_id: nil,
        player_o: %{id: 1, name: "Olga"},
        player_x: %{id: 2, name: "Xavier"}
      },
      attrs
    )
  end

  defp user(id), do: %{id: id}

  describe "role/2" do
    test "returns :spectator for nil user" do
      assert GamePresenter.role(game(), nil) == :spectator
    end

    test "returns :player_o when user is player_o" do
      assert GamePresenter.role(game(), user(1)) == :player_o
    end

    test "returns :player_x when user is player_x" do
      assert GamePresenter.role(game(), user(2)) == :player_x
    end

    test "returns :spectator for unrelated user" do
      assert GamePresenter.role(game(), user(99)) == :spectator
    end
  end

  describe "your_mark/2" do
    test "returns :o for player_o" do
      assert GamePresenter.your_mark(game(), user(1)) == :o
    end

    test "returns :x for player_x" do
      assert GamePresenter.your_mark(game(), user(2)) == :x
    end

    test "returns nil for spectator" do
      assert GamePresenter.your_mark(game(), nil) == nil
    end
  end

  describe "clickable_fields/2" do
    test "returns available_fields when it is the user's turn" do
      g = game(%{next_player_id: 1, available_fields: [0, 3, 7]})
      assert GamePresenter.clickable_fields(g, user(1)) == [0, 3, 7]
    end

    test "returns empty list when it is not the user's turn" do
      g = game(%{next_player_id: 1})
      assert GamePresenter.clickable_fields(g, user(2)) == []
    end

    test "returns empty list for spectator" do
      assert GamePresenter.clickable_fields(game(), nil) == []
    end

    test "returns empty list when game is not active" do
      g = game(%{state: :won, next_player_id: 1})
      assert GamePresenter.clickable_fields(g, user(1)) == []
    end

    test "returns empty list when game is open" do
      g = game(%{state: :open, next_player_id: 1})
      assert GamePresenter.clickable_fields(g, user(1)) == []
    end
  end

  describe "status_text/2" do
    test "open game" do
      g = game(%{state: :open})
      assert GamePresenter.status_text(g, user(1)) == "Waiting for an opponent to join"
    end

    test "draw" do
      g = game(%{state: :draw})
      assert GamePresenter.status_text(g, user(1)) == "It's a draw!"
    end

    test "active game, your turn" do
      g = game(%{state: :active, next_player_id: 1})
      assert GamePresenter.status_text(g, user(1)) == "Your turn"
    end

    test "active game, opponent's turn (you are player_o)" do
      g = game(%{state: :active, next_player_id: 2})
      assert GamePresenter.status_text(g, user(1)) == "Xavier is thinking..."
    end

    test "active game, spectator" do
      g = game(%{state: :active, next_player_id: 1})
      assert GamePresenter.status_text(g, nil) == "Olga's turn"
    end

    test "won game, you won" do
      g = game(%{state: :won, winner_id: 1})
      assert GamePresenter.status_text(g, user(1)) == "You won!"
    end

    test "won game, you lost" do
      g = game(%{state: :won, winner_id: 1})
      assert GamePresenter.status_text(g, user(2)) == "Olga won"
    end

    test "won game, spectator sees winner" do
      g = game(%{state: :won, winner_id: 1})
      assert GamePresenter.status_text(g, nil) == "Olga won!"
    end
  end

  describe "winner_name/1" do
    test "returns winner name when player_o won" do
      g = game(%{winner_id: 1})
      assert GamePresenter.winner_name(g) == "Olga"
    end

    test "returns winner name when player_x won" do
      g = game(%{winner_id: 2})
      assert GamePresenter.winner_name(g) == "Xavier"
    end

    test "returns nil when no winner" do
      g = game(%{winner_id: nil})
      assert GamePresenter.winner_name(g) == nil
    end
  end

  describe "player_display/3" do
    test "returns display map for player_o" do
      g = game(%{state: :active, next_player_id: 1, winner_id: nil})
      result = GamePresenter.player_display(g, :player_o, user(1))

      assert result == %{
               name: "Olga",
               mark: :o,
               is_turn: true,
               is_winner: false,
               is_you: true
             }
    end

    test "returns display map for player_x as spectator" do
      g = game(%{state: :active, next_player_id: 2, winner_id: nil})
      result = GamePresenter.player_display(g, :player_x, nil)

      assert result == %{
               name: "Xavier",
               mark: :x,
               is_turn: true,
               is_winner: false,
               is_you: false
             }
    end

    test "marks winner correctly" do
      g = game(%{state: :won, next_player_id: 1, winner_id: 2})
      result = GamePresenter.player_display(g, :player_x, user(2))

      assert result == %{
               name: "Xavier",
               mark: :x,
               is_turn: false,
               is_winner: true,
               is_you: true
             }
    end
  end
end
