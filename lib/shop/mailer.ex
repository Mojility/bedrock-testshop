defmodule Shop.Mailer do
  @moduledoc """
  Sends the system's email. Amazon SES in production, the local mailbox at
  `/dev/mailbox` in development, Swoosh's test adapter in test.
  """
  use Swoosh.Mailer, otp_app: :shop

  @doc """
  The address every email is sent from, as `{name, address}`: the
  configured `:mail_from` address (`MAIL_FROM` in production) with its own
  display name when it carries one, and the shop's name otherwise.
  """
  @spec from_address() :: {String.t(), String.t()}
  def from_address do
    case parse_address(Application.fetch_env!(:shop, :mail_from)) do
      {"", address} -> {Shop.name(), address}
      named -> named
    end
  end

  @doc """
  Parses a display-name address into a `{name, address}` tuple. A bare
  address has an empty name.

      iex> Shop.Mailer.parse_address("Acme <hello@example.com>")
      {"Acme", "hello@example.com"}

      iex> Shop.Mailer.parse_address("hello@example.com")
      {"", "hello@example.com"}
  """
  @spec parse_address(String.t()) :: {String.t(), String.t()}
  def parse_address(from) when is_binary(from) do
    case Regex.run(~r/^\s*(.*?)\s*<([^>]+)>\s*$/, from) do
      [_, name, address] -> {name, address}
      nil -> {"", String.trim(from)}
    end
  end
end
