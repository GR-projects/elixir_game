defmodule Web.Components.Equipment do
  use Phoenix.Component

  attr :item, :map, default: nil

  def render_slot(assigns) do
    ~H"""
    <div
      class="w-20 h-20 border-2 border-gray-600 flex items-center justify-center bg-gray-700 rounded-lg"
      title={if @item, do: @item.name, else: "Empty"}
    >
      <%= if @item do %>
        <img src={@item.sprite} alt={@item.name} class="w-full h-full object-contain" />
        <div class="absolute bottom-0 left-0 w-full bg-black bg-opacity-75 text-xs text-white text-center p-1 hidden group-hover:block">
          <%= "HP: #{@item.stats.health}, Att: #{@item.stats.physical_att}/#{@item.stats.magical_att}, Def: #{@item.stats.physical_def}/#{@item.stats.magical_def}" %>
        </div>
      <% else %>
        <span class="text-gray-500"></span>
      <% end %>
    </div>
    """
  end
end
