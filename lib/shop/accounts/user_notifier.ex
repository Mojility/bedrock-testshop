defmodule Shop.Accounts.UserNotifier do
  @moduledoc """
  The emails an account sends: plain text, and the link is the whole point.
  """
  import Swoosh.Email

  alias Shop.Accounts.User
  alias Shop.Mailer

  @doc """
  Deliver instructions to update a user email.
  """
  def deliver_update_email_instructions(user, url) do
    deliver(user.email, "Confirm your new email for #{Shop.name()}", """
    Hi #{user.email},

    Open this link to change the email on your #{Shop.name()} account:

    #{url}

    If you didn't ask for this change, ignore this email and nothing happens.
    """)
  end

  @doc """
  Deliver the magic link. For a user who has not yet confirmed their email
  this is the confirmation; for everyone else it is a sign-in link.
  """
  def deliver_login_instructions(user, url) do
    case user do
      %User{confirmed_at: nil} -> deliver_confirmation_instructions(user, url)
      _ -> deliver_magic_link_instructions(user, url)
    end
  end

  defp deliver_magic_link_instructions(user, url) do
    deliver(user.email, "Your #{Shop.name()} sign-in link", """
    Hi #{user.email},

    Here is your link to sign in to #{Shop.name()}:

    #{url}

    Open it on the device you want to use. It works once and expires soon.

    If you didn't ask for this, ignore this email and nothing happens.
    """)
  end

  defp deliver_confirmation_instructions(user, url) do
    deliver(user.email, "Confirm your #{Shop.name()} account", """
    Hi #{user.email},

    Open this link to confirm your email and sign in to #{Shop.name()}:

    #{url}

    Opening it confirms the address is right, which matters: a link like this
    one is the only way into your account. There is no password.

    If you didn't create an account, ignore this email and nothing happens.
    """)
  end

  defp deliver(recipient, subject, body) do
    email =
      new()
      |> to(recipient)
      |> from(Mailer.from_address())
      |> subject(subject)
      |> text_body(body)

    with {:ok, _metadata} <- Mailer.deliver(email) do
      {:ok, email}
    end
  end
end
