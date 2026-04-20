defmodule Xo.Accounts.UserTest do
  use Xo.DataCase, async: true

  import Xo.Generators.User

  alias Xo.Accounts.User

  describe "attributes" do
    test "email is case-insensitive" do
      user = generate(user(%{email: "Test@Example.COM"}))

      assert to_string(user.email) == "Test@Example.COM"
    end

    test "has an integer primary key" do
      user = generate(user())

      assert is_integer(user.id)
    end

    test "name is required" do
      assert_raise Ash.Error.Unknown, fn ->
        generate(user(%{name: nil}))
      end
    end

    test "name is stored as a string" do
      user = generate(user(%{name: "Alice"}))

      assert user.name == "Alice"
    end
  end

  describe "identities" do
    test "enforces unique email" do
      generate(user(%{email: "dupe@example.com"}))

      assert_raise Ash.Error.Invalid, fn ->
        generate(user(%{email: "dupe@example.com"}))
      end
    end
  end

  describe "read actions" do
    test "get_by_email returns user with matching email" do
      seeded = generate(user(%{email: "lookup@example.com"}))

      assert {:ok, found} =
               Ash.get(User, %{email: "lookup@example.com"}, authorize?: false)

      assert found.id == seeded.id
    end

    test "get_by_email returns not found for unknown email" do
      assert {:error, %Ash.Error.Invalid{}} =
               Ash.get(User, %{email: "unknown@example.com"}, authorize?: false)
    end

    test "read returns all users" do
      user1 = generate(user())
      user2 = generate(user())

      assert {:ok, users} = Ash.read(User, authorize?: false)
      ids = Enum.map(users, & &1.id)

      assert user1.id in ids
      assert user2.id in ids
    end
  end

  describe "demo_create_user" do
    test "Creates a user" do
      assert {:ok, %User{} = user} = Xo.Accounts.demo_create_user("hans")
      assert to_string(user.email) == "hans@example.com"
    end

    test "Returns exisiting user" do
      existing = generate(user())

      assert {:ok, user} =
               Xo.Accounts.demo_create_user(
                 existing.name,
                 existing.email
               )

      assert user.name == existing.name
      assert user.email == existing.email
    end
  end
end
