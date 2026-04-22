defmodule Web.Emails.Sender do
  alias Web.Mailer
  alias Swoosh.Email

  def deliver_confirmation_email(user, token, base_url) do
    confirm_url = "#{base_url}/confirm/#{token}"

    Email.new()
    |> Email.to({user.name, user.email})
    |> Email.from({"noreply", "noreply@#{host_from_base_url(base_url)}"})
    |> Email.subject("Confirm your email")
    |> Email.html_body(confirmation_html(confirm_url, user.name))
    |> Email.text_body(confirmation_text(confirm_url, user.name))
    |> Mailer.deliver()
  end

  defp host_from_base_url(base_url) do
    base_url
    |> URI.parse()
    |> Map.get(:host)
    |> Kernel.to_string()
  end

  defp confirmation_html(url, name) do
    """
    <html>
      <body style="font-family: Arial, sans-serif; max-width: 600px; margin: 0 auto;">
        <h2>Welcome, #{name}!</h2>
        <p>Thank you for registering. Please confirm your email address by clicking the button below:</p>
        <p>
          <a href="#{url}" style="background-color: #4F46E5; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; display: inline-block;">
            Confirm Email
          </a>
        </p>
        <p>Or copy and paste this link in your browser:</p>
        <p><a href="#{url}">#{url}</a></p>
        <p style="color: #6B7280; font-size: 12px; margin-top: 24px;">
          This link will expire in 24 hours.
        </p>
      </body>
    </html>
    """
  end

  defp confirmation_text(url, name) do
    """
    Welcome, #{name}!

    Thank you for registering. Please confirm your email address by visiting:
    #{url}

    This link will expire in 24 hours.
    """
  end
end
