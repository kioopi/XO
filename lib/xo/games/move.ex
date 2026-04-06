defmodule Xo.Games.Move do
  use Ash.Resource, otp_app: :xo, domain: Xo.Games, data_layer: AshPostgres.DataLayer

  alias Xo.Games.Move.Changes
  alias Xo.Games.Move.Validations

  postgres do
    table "moves"
    repo Xo.Repo
  end

  actions do
    defaults [:read]

    create :create do
      description "Record a move in a game."
      primary? true
      accept [:field, :game_id]

      change relate_actor(:player, allow_nil?: false)
      change Changes.LoadGame
      change Changes.SetMoveNumber
      validate Validations.ValidatePlayerTurn
    end
  end

  attributes do
    integer_primary_key :id

    attribute :field, :integer do
      description "Board position (0-8) where the move is placed."
      allow_nil? false
      public? true
    end

    attribute :move_number, :integer do
      description "Sequential move number within the game, starting at 1."
      allow_nil? false
      public? true
    end

    timestamps()
  end

  relationships do
    belongs_to :player, Xo.Accounts.User do
      description "The user who made this move."
      public? true
      allow_nil? false
      attribute_type :integer
    end

    belongs_to :game, Xo.Games.Game do
      description "The game this move belongs to."
      public? true
      allow_nil? false
      attribute_type :integer
    end
  end

  identities do
    identity :unique_field_per_game, [:game_id, :field],
      description: "Each board position can only be played once per game."

    identity :unique_move_number_per_game, [:game_id, :move_number],
      description: "Each move number is unique within a game."
  end
end
