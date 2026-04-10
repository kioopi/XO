defmodule Xo.Games do
  @moduledoc "Manages tic-tac-toe games, moves, and gameplay."

  use Ash.Domain,
    otp_app: :xo,
    extensions: [AshPhoenix],
    fragments: [Xo.Games.Commentator.DomainFragment]

  resources do
    resource Xo.Games.Game do
      define :create_game, action: :create
      define :list_open_games, action: :open
      define :list_active_games, action: :active
      define :join, action: :join
      define :make_move, action: :make_move, args: [:field]
      define :get_by_id, action: :read, get_by: [:id]
    end

    resource Xo.Games.Move

    resource Xo.Games.Message do
      define :create_message, action: :create, args: [:body]
      define :list_messages, action: :by_game, args: [:game_id]
    end
  end
end
