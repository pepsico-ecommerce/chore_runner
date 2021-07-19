defmodule ChoreUi.Components.ChoreItemComponent do
  use Phoenix.LiveComponent
  alias ChoreUI.ChoreView

  def render(assigns) do
    ChoreView.render("chore_item.html", assigns)
  end
end
