defmodule Web.Messages do
  def user_registration_success, do: "User successfully registered"

  def user_registration_failure, do: "Error during user registration"
  def user_not_logged_in, do: "User not logged in"
  def user_login_success, do: "User logged in."
  def user_login_failure, do: "Cannot log in user. Try again"
end
