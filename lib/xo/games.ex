defmodule Xo.Games do
  use Ash.Domain,
    otp_app: :xo

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
  end
end
