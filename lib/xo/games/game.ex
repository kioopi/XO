defmodule Xo.Games.Game do
  use Ash.Resource,
    otp_app: :xo,
    domain: Xo.Games,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer],
    notifiers: [Ash.Notifier.PubSub],
    fragments: [Xo.Games.Commentator.GameFragment, Xo.Games.Bot.GameFragment]

  alias Xo.Accounts.User
  alias Xo.Games.Validations.ValidateGameState
  alias Xo.Games.Changes

  postgres do
    table "games"
    repo Xo.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :open,
      filter: expr(state == :open),
      description: "List games waiting for a second player."

    read :active,
      filter: expr(state == :active),
      description: "List games currently in progress."

    create :create do
      description "Start a new game. The acting user becomes player O."
      change relate_actor(:player_o, allow_nil?: false)
    end

    update :join do
      description "Join an open game as player X."
      require_atomic? false

      validate {ValidateGameState, states: [:open]}
      change relate_actor(:player_x, allow_nil?: false)
      change Xo.Games.Commentator.StartCommentator
    end

    update :make_move do
      description "Place a move on the board."
      require_atomic? false

      argument :field, :integer do
        description "Board position (0-8), numbered left-to-right, top-to-bottom."
        allow_nil? false
        constraints min: 0, max: 8
      end

      validate {ValidateGameState, states: :active}
      change Changes.CreateMove
    end
  end

  policies do
    policy action_type(:read) do
      description "Anyone can view games."
      authorize_if always()
    end

    policy action_type(:create) do
      description "Authenticated users can create games."
      authorize_if actor_present()
    end

    policy action(:join) do
      description "A different authenticated user can join an open game."
      forbid_unless actor_present()
      forbid_unless expr(is_nil(player_x_id))
      forbid_unless expr(player_o_id != ^actor(:id))
      authorize_if always()
    end

    policy action(:make_move) do
      description "Only the player whose turn it is can move."
      forbid_unless actor_present()
      authorize_if expr(next_player_id == ^actor(:id))
    end
  end

  pub_sub do
    module XoWeb.Endpoint
    prefix "game"

    publish :create, "created", load: [:state, :player_o]
    publish :create, "lobby"

    publish :join, ["activity", :_pkey]
    publish :join, [:_pkey], load: [:state, :board, :player_o, :player_x, :next_player_id]
    publish :join, "lobby"

    publish :make_move, [:_pkey],
      load: [:state, :board, :winner_id, :next_player_id, :available_fields]

    publish :destroy, ["activity", :_pkey]
    publish :destroy, [:_pkey]
    publish :destroy, "lobby"
  end

  attributes do
    integer_primary_key :id

    timestamps()
  end

  relationships do
    belongs_to :player_o, User do
      description "The user who created the game and plays as O."
      public? true
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :player_x, User do
      description "The user who joined the game and plays as X."
      public? true
      attribute_type :integer
    end

    has_many :moves, Xo.Games.Move, description: "All moves made in this game."
    has_many :messages, Xo.Games.Message, description: "Chat messages sent during this game."
  end

  calculations do
    calculate :winner_id, :integer, Calculations.WinnerId,
      description: "The user ID of the winning player, or nil."

    calculate :state, :atom, Calculations.GameState,
      description: "Derived game state: :open, :active, :won, or :draw."

    calculate :next_move_number, :integer, expr(move_count + 1),
      description: "The sequence number for the next move."

    calculate :next_player_id,
              :integer,
              expr(if(rem(move_count, 2) == 0, player_o_id, player_x_id)),
              description: "The user ID of the player whose turn it is."

    calculate :board, {:array, :atom}, Calculations.Board,
      description: "The board as a 9-element list of :o, :x, or nil."

    calculate :available_fields, {:array, :integer}, Calculations.AvailableFields,
      description: "Board positions not yet played."
  end

  aggregates do
    count :move_count, :moves, description: "Total number of moves made in this game."

    list :player_o_fields, :moves, :field do
      description "Board positions played by player O."
      filter expr(player_id == parent(player_o_id))
    end

    list :player_x_fields, :moves, :field do
      description "Board positions played by player X."
      filter expr(player_id == parent(player_x_id))
    end
  end
end
