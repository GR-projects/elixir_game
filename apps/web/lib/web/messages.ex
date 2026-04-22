defmodule Web.Messages do
  def user_registration_success, do: "User successfully registered"
  def user_registration_failure, do: "Error during user registration"
  def user_registration_sent, do: "Registration successful! Please check your email to confirm your account."

  def user_not_logged_in, do: "User not logged in"
  def user_login_success, do: "User logged in."
  def user_login_failure, do: "Cannot log in user. Try again"
  def user_not_confirmed, do: "Email not confirmed. Please check your email or request a new confirmation link."
  def user_confirmed, do: "Email confirmed! You can now log in."
  def user_already_confirmed, do: "Your email is already confirmed."

  def confirmation_invalid, do: "Invalid confirmation link. Please request a new one."
  def confirmation_expired, do: "Confirmation link has expired. Please register again."
  def confirmation_resent, do: "Confirmation email sent! Please check your inbox."

  def user_not_found, do: "User not found."

  def character_create_failure, do: "Couldnt create character. Try again"
  def character_get_failure, do: "Couldnt get character"
  def character_delete_failure, do: "Couldnt delete character"
end
