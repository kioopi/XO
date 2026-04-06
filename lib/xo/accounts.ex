defmodule Xo.Accounts do
  @moduledoc "Manages user accounts and authentication."

  use Ash.Domain, otp_app: :xo, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Xo.Accounts.Token
    resource Xo.Accounts.User do
      define :demo_create_user, action: :demo_create, args: [:name, {:optional, :email}]
      define :demo_sign_in, action: :demo_sign_in, args: [:name, {:optional, :email}]
    end
  end
end
