defmodule Business.MailerTest do
  use ExUnit.Case, async: false

  alias Business.Mailer

  doctest Business.Mailer

  setup do
    original = Application.fetch_env!(:business, :mail_from)
    on_exit(fn -> Application.put_env(:business, :mail_from, original) end)
    :ok
  end

  describe "from_address/0" do
    test "names a bare address after the business" do
      Application.put_env(:business, :mail_from, "noreply@example.com")
      assert Mailer.from_address() == {Business.name(), "noreply@example.com"}
    end

    test "keeps a display name the address carries" do
      Application.put_env(:business, :mail_from, "Front Desk <hello@example.com>")
      assert Mailer.from_address() == {"Front Desk", "hello@example.com"}
    end
  end
end
