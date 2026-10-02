defmodule Business.SmokeFault do
  @moduledoc false
  import Plug.Conn
  import Ecto.Query

  def init(options), do: options

  # Each independent HTTP test gets a fresh visitor budget. The production
  # limiter and its rejection tests retain their configured limit.
  def reset_loopback_rate_limit do
    :ets.match_delete(Business.Leads.RateLimiter, {{{127, 0, 0, 1}, :_}, :_})
  end

  def call(conn, %{fault: :empty_css}) when conn.request_path == "/assets/published/site.css" do
    conn |> put_resp_content_type("text/css") |> send_resp(200, "")
  end

  def call(conn, %{fault: :html_css}) when conn.request_path == "/assets/published/site.css" do
    conn |> put_resp_content_type("text/html") |> send_resp(200, "<html>Unavailable</html>")
  end

  def call(conn, %{fault: :staff_css}) when conn.request_path == "/assets/css/app.css" do
    conn |> put_resp_content_type("text/css") |> send_resp(200, "")
  end

  def call(conn, %{fault: :private_access}) when conn.request_path == "/app/leads" do
    send_resp(conn, 200, "Private records exposed")
  end

  def call(conn, %{fault: :csrf}) when conn.request_path == "/leads" do
    send_resp(conn, 200, "Submission accepted without CSRF")
  end

  def call(conn, %{fault: :sign_in}) when conn.request_path == "/users/log-in" do
    send_resp(conn, 403, "Magic link rejected")
  end

  def call(conn, %{fault: :persistence}) when conn.request_path == "/leads" do
    conn = Plug.Parsers.call(conn, Plug.Parsers.init(parsers: [:urlencoded]))

    if conn.params["_csrf_token"] do
      conn |> put_resp_header("location", "/?sent=1") |> send_resp(302, "")
    else
      BusinessWeb.Endpoint.call(conn, [])
    end
  end

  def call(conn, %{fault: :corrupt_submission}) when conn.request_path == "/leads" do
    conn
    |> register_before_send(fn response ->
      Business.Repo.update_all(
        from(l in Business.Leads.Lead, where: like(l.name, "Smoke %")),
        set: [phone: "555-0199", message: "Lost request"]
      )

      response
    end)
    |> BusinessWeb.Endpoint.call([])
  end

  def call(conn, %{fault: :corrupt_retained, lead_id: id})
      when conn.request_path == "/app/leads" do
    Business.Repo.update_all(from(l in Business.Leads.Lead, where: l.id == ^id),
      set: [notes: "Lost follow-up", status: "new"]
    )

    BusinessWeb.Endpoint.call(conn, [])
  end

  def call(conn, %{fault: :missing_retained, lead_id: id})
      when conn.request_path == "/app/leads" do
    Business.Repo.delete_all(from(l in Business.Leads.Lead, where: l.id == ^id))
    BusinessWeb.Endpoint.call(conn, [])
  end

  def call(conn, %{fault: fault, lead_id: id, observer: observer}) do
    conn
    |> register_before_send(fn response ->
      body = IO.iodata_to_binary(response.resp_body || "")

      body =
        case {fault, response.status, conn.request_path} do
          {:lead_form, 200, "/"} ->
            remove_content(
              body,
              ~r/<form\b(?=[^>]*\bid="lead-form")[^>]*>.*?<\/form>/s,
              fault,
              observer,
              form_placeholder(body)
            )

          {:staff_read, 200, "/app/leads"} ->
            remove_content(
              body,
              ~r/<ol\b(?=[^>]*\bid="leads-list")[^>]*>.*?<\/ol>/s,
              fault,
              observer,
              ~s(<ol id="leads-list"></ol>)
            )

          {:retained_read, 200, "/app/leads"} ->
            remove_content(
              body,
              ~r/<li\b(?=[^>]*\bid="leads-#{id}")[^>]*>.*?<\/li>/s,
              fault,
              observer,
              ~s(<li id="leads-#{id}"></li>)
            )

          {:digested_css, _, _} ->
            String.replace(body, "/assets/published/site.css", "/assets/published/site.css?vsn=d")

          _ ->
            body
        end

      %{response | resp_body: body}
    end)
    |> BusinessWeb.Endpoint.call([])
  end

  defp form_placeholder(body) do
    # Keep the old marker and CSRF field: a direct synthetic POST can still
    # work, but the visitor has no enquiry form or contact/request controls.
    [csrf] = Regex.run(~r/<input\b[^>]*name="_csrf_token"[^>]*>/, body)
    ~s(<div id="lead-form">#{csrf}</div>)
  end

  defp remove_content(body, pattern, fault, observer, replacement) do
    # Remove the complete control/result, rather than renaming a marker. The
    # observer receives the actual response that crosses the HTTP boundary.
    body = Regex.replace(pattern, body, replacement)
    send(observer, {:capability_loss, fault, body})
    body
  end
end
