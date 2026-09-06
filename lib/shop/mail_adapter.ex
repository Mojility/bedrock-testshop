defmodule Shop.MailAdapter do
  @moduledoc "SES using this application's renewable credentials, in Canada only."
  use Swoosh.Adapter, required_config: []

  def deliver(email, _config) do
    with {:ok, credentials} <- Shop.RuntimeCredentials.read() do
      email = Swoosh.Email.put_provider_option(email, :security_token, credentials[:token])

      Swoosh.Adapters.AmazonSES.deliver(email,
        access_key: credentials[:access_key_id],
        secret: credentials[:secret_access_key],
        region: "ca-central-1"
      )
    end
  end
end
