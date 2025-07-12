defmodule Web.CharacterHTML do
  @moduledoc """
  This module contains pages rendered by CharacterController.

  See the `auth_templates` and `page_html` directories for all templates available.
  """
  use Web, :html

  embed_templates "page_html/*"
end
