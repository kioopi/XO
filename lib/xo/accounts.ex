defmodule Xo.Accounts do
  use Ash.Domain, otp_app: :xo, extensions: [AshAdmin.Domain]

  admin do
    show? true
  end

  resources do
    resource Xo.Accounts.Token
    resource Xo.Accounts.User
  end
end
