# Called only inside a synthetic snapshot by qualify_business_name.py.
endpoint = Application.fetch_env!(:business, BusinessWeb.Endpoint)

Application.put_env(
  :business,
  BusinessWeb.Endpoint,
  Keyword.merge(endpoint,
    server: true,
    http: [ip: {127, 0, 0, 1}, port: String.to_integer(System.get_env("NAME_PORT", "4000"))]
  )
)

{:ok, _} = Application.ensure_all_started(:business)
{:ok, {_address, port}} = BusinessWeb.Endpoint.server_info(:http)
expected = System.fetch_env!("NAME_EXPECTED")
title_expected = System.fetch_env!("NAME_TITLE_EXPECTED")

unless Business.name() == expected, do: raise("Business.name() corrupted the input")

for theme <- ["light", "dark"], path <- ["/", "/users/log-in"] do
  response = Req.get!("http://127.0.0.1:#{port}" <> path, headers: [{"cookie", "theme=#{theme}"}])
  unless response.status == 200, do: raise("HTTP request failed")
  document = LazyHTML.from_document(response.body)
  title = document |> LazyHTML.query("title") |> LazyHTML.text() |> String.trim()
  header = document |> LazyHTML.query("header a[href='/']") |> LazyHTML.text() |> String.trim()
  unless title == title_expected, do: raise("Page title corrupted the input")
  unless header == expected, do: raise("Header corrupted the input")

  if path == "/" do
    heading = document |> LazyHTML.query("#home h1") |> LazyHTML.text() |> String.trim()
    unless heading == expected, do: raise("Home heading corrupted the input")
  end
end

unless Business.Mailer.from_address() == {expected, "noreply@localhost"},
  do: raise("Mail sender corrupted the input")

{:ok, email} =
  Business.Accounts.UserNotifier.deliver_login_instructions(
    %Business.Accounts.User{email: "synthetic@example.invalid", confirmed_at: DateTime.utc_now()},
    "https://example.invalid/synthetic-sign-in"
  )

unless email.subject == "Your #{expected} sign-in link" and
         String.contains?(email.text_body, "sign in to #{expected}:"),
       do: raise("Magic-link notification corrupted the input")

IO.puts("Business.name(), real HTTP titles/header/home and email names preserve the name")
