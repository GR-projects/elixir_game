defmodule Web.Components.Equipment do
  @moduledoc """
  Components for displaying equipment slots and items.
  """
  use Phoenix.Component

  attr :item, :map, default: nil

  def render_slot(assigns) do
    ~H"""
    <div
      class={"equipment-slot #{if @item, do: "filled", else: ""}"}
      title={if @item, do: @item.name, else: "Empty"}
    >
      <%= if @item do %>
        <img src={@item.sprite} alt={@item.name} class="w-full h-full object-contain p-1.5 rounded" />
        <!-- Hover tooltip -->
        <div class="rpg-tooltip bottom-full left-1/2 -translate-x-1/2 mb-2 w-52">
          <p class="font-display text-gold-400 text-xs font-semibold mb-1"><%= @item.name %></p>
          <div class="rpg-divider mb-1.5"></div>
          <div class="space-y-0.5 text-[0.65rem]">
            <p><span class="text-emerald-400">HP:</span> <%= @item.stats.health %></p>
            <p>
              <span class="text-crimson-300">Phys Att:</span> <%= @item.stats.physical_att %>
              &middot;
              <span class="text-arcane-300">Mag Att:</span> <%= @item.stats.magical_att %>
            </p>
            <p>
              <span class="text-yellow-300">Phys Def:</span> <%= @item.stats.physical_def %>
              &middot;
              <span class="text-blue-300">Mag Def:</span> <%= @item.stats.magical_def %>
            </p>
          </div>
        </div>
      <% else %>
        <span class="text-dark-500">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 20 20" fill="currentColor" class="w-5 h-5">
            <path d="M10.75 4.75a.75.75 0 00-1.5 0v4.5h-4.5a.75.75 0 000 1.5h4.5v4.5a.75.75 0 001.5 0v-4.5h4.5a.75.75 0 000-1.5h-4.5v-4.5z" />
          </svg>
        </span>
      <% end %>
    </div>
    """
  end
end
