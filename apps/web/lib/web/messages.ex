defmodule Web.Messages do
  def user_registration_success, do: "User successfully registered"

  def user_registration_failure, do: "Error during user registration"
  def user_not_logged_in, do: "User not logged in"
  def user_login_success, do: "User logged in."
  def user_login_failure, do: "Cannot log in user. Try again"
  def character_create_failure, do: "Couldnt create character. Try again"
  def character_get_failure, do: "Couldnt get character"
  def character_delete_failure, do: "Couldnt delete character"
end
