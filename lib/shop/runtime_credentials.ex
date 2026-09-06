defmodule Shop.RuntimeCredentials do
  @moduledoc "Reads atomically renewed credentials belonging only to this application."
  # Credential path is operator configuration, never request input; malformed/expired files fail closed.
  # sobelow_skip ["Traversal.FileModule"]
  def read do
    with path when is_binary(path) <- Application.get_env(:shop, :aws_credentials_file),
         {:ok, bytes} <- File.read(path),
         {:ok,
          %{
            "AccessKeyId" => key,
            "SecretAccessKey" => secret,
            "SessionToken" => token,
            "Expiration" => expires
          }} <- Jason.decode(bytes),
         {:ok, expiry, _} <- DateTime.from_iso8601(expires),
         true <- DateTime.diff(expiry, DateTime.utc_now()) > 30 do
      {:ok, [access_key_id: key, secret_access_key: secret, token: token, region: "ca-central-1"]}
    else
      _ -> {:error, :credentials_unavailable}
    end
  end
end
