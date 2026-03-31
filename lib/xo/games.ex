defmodule Xo.Games do
  use Ash.Domain,
    otp_app: :xo

  resources do
    resource Xo.Games.Game
  end
end
