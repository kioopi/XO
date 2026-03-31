defmodule Xo.Games.Game do
  use Ash.Resource,
    otp_app: :xo,
    domain: Xo.Games,
    extensions: [AshStateMachine],
    data_layer: AshPostgres.DataLayer,
    authorizers: [Ash.Policy.Authorizer]

  alias Xo.Accounts.User

  state_machine do
    initial_states [:open]
    default_initial_state :open

    transitions do
      transition :join, from: :open, to: :active
      transition :make_move, from: :active, to: [:active, :won, :draw]
    end
  end

  postgres do
    table "games"
    repo Xo.Repo
  end

  actions do
    defaults [:read, :destroy]

    create :create do
      change relate_actor(:player_o, allow_nil?: false)
    end

    update :join do
      change relate_actor(:player_x, allow_nil?: false)
      change transition_state(:active)
    end

    update :make_move do
      argument :field, :integer do
        allow_nil? false
        constraints min: 0, max: 8
      end

      change transition_state(:active)
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
      authorize_if expr(player_o_id == ^actor(:id) or player_x_id == ^actor(:id))
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

    belongs_to :winner, User do
      public? true
    end
  end
end
