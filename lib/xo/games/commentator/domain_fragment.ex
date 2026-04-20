defmodule Xo.Games.Commentator.DomainFragment do
  use Spark.Dsl.Fragment,
    of: Ash.Domain,
    extensions: [AshAi]

  tools do
    tool :read_game, Xo.Games.Game, :read do
      description "Read game details including board state, players, and current status."
      load [:state, :board, :player_o, :player_x, :winner_id, :next_player_id, :move_count]
    end

    tool :read_moves, Xo.Games.Move, :read do
      description "Read the moves made in a game, including which player made each move and the board position."
      load [:player]
    end
  end

  resources do
    resource Xo.Games.Game do
      define :generate_commentary,
        action: :generate_commentary,
        args: [:game_id, :event_description]
    end

    resource Xo.Games.Message do
      define :post_commentary,
        action: :post_commentary,
        args: [:game_id, :event_description]
    end
  end
end
