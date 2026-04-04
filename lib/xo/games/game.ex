defmodule Xo.Games.Game do
  use Ash.Resource,
    otp_app: :xo,
    domain: Xo.Games,
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Xo.Accounts.User

  postgres do
    table "games"
    repo Xo.Repo
  end

  actions do
    defaults [:read, :destroy]

    read :open, filter: expr(state == :open)

    create :create do
      change relate_actor(:player_o, allow_nil?: false)
    end

    update :join do
      require_atomic? false

      validate {Xo.Games.Validations.ValidateGameState, states: [:open]}
      change relate_actor(:player_x, allow_nil?: false)
    end

    update :make_move do
      require_atomic? false

      argument :field, :integer do
        allow_nil? false
        constraints min: 0, max: 8
      end

      validate {Xo.Games.Validations.ValidateGameState, states: :active}
      change Xo.Games.Changes.CreateMove
    end
  end

  policies do
    policy action_type(:read) do
      authorize_if always()
    end

    policy action_type(:create) do
      authorize_if actor_present()
    end

    policy action(:join) do
      forbid_unless actor_present()
      forbid_unless expr(is_nil(player_x_id))
      forbid_unless expr(player_o_id != ^actor(:id))
      authorize_if always()
    end

    policy action(:make_move) do
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
      public? true
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :player_x, User do
      public? true
      attribute_type :integer
    end

    has_many :moves, Xo.Games.Move
  end

  calculations do
    calculate :winner_id, :integer, Xo.Games.Calculations.WinnerId
    calculate :state, :atom, Xo.Games.Calculations.GameState
    calculate :next_move_number, :integer, expr(move_count + 1)

    calculate :next_player_id,
              :integer,
              expr(if(rem(move_count, 2) == 0, player_o_id, player_x_id))

    calculate :board, {:array, :atom}, Xo.Games.Calculations.Board
    calculate :available_fields, {:array, :integer}, Xo.Games.Calculations.AvailableFields
  end

  aggregates do
    count :move_count, :moves

    list :player_o_fields, :moves, :field do
      filter expr(player_id == parent(player_o_id))
    end

    list :player_x_fields, :moves, :field do
      filter expr(player_id == parent(player_x_id))
    end
  end
end
