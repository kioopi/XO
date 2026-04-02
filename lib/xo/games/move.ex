defmodule Xo.Games.Move do
  use Ash.Resource, otp_app: :xo, domain: Xo.Games, data_layer: AshPostgres.DataLayer

  postgres do
    table "moves"
    repo Xo.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:field, :game_id]

      change relate_actor(:player, allow_nil?: false)
      change Xo.Games.Move.Changes.LoadGame
      change Xo.Games.Move.Changes.SetMoveNumber
      validate Xo.Games.Move.Validations.ValidatePlayerTurn
    end
  end

  attributes do
    integer_primary_key :id

    attribute :field, :integer do
      allow_nil? false
      public? true
    end

    attribute :move_number, :integer do
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :player, Xo.Accounts.User do
      public? true
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :game, Xo.Games.Game do
      public? true
      allow_nil? false
      attribute_type :integer
    end
  end

  identities do
    identity :unique_field_per_game, [:game_id, :field]
    identity :unique_move_number_per_game, [:game_id, :move_number]
  end
end
