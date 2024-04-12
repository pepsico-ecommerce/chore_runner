defmodule ChoreRunnerUI.Components.ChoreModalComponent do
  use Phoenix.LiveComponent

  def render(assigns) do
    ~H"""
    <div>
      <%= if @chore do %>
        <div class="chore-modal-backdrop" phx-click="deselect_chore">
        </div>
        <div class="chore-modal-container" id={"#{@chore.id}-modal"}>
          <div class="chore-modal-header">
            <h2><%= @chore.__struct__%></h2>
            <button phx-click="deselect_chore"> X</button>
          </div>
          <div class="chore-modal-text-container">
            <%= for {message, timestamp} <- @chore.logs do %>
              <p id={"#{@chore.id}-#{timestamp}"}><%= timestamp %> <%= message %></p>
            <% end %>
          </div>
          <div class="chore-modal-bottom-container">
            <button phx-click="deselect_chore">Close</button>
          </div>
        </div>
      <% end %>
    </div>
    """
  end
end
