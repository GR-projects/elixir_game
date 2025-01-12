defmodule Web.AuthHTML do
  @moduledoc """
  This module contains pages rendered by AuthController.

  See the `auth_templates` directory for all templates available.
  """
  use Web, :html

  embed_templates "auth_templates/*"
end
