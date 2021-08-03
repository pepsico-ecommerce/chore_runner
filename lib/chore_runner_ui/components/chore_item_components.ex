defmodule ChoreRunnerUI.Components.ChoreItemComponent do
  use Phoenix.LiveComponent
  alias ChoreRunnerUI.ChoreView

  def render(assigns) do
    ChoreView.render("chore_item.html", assigns)
  end
end
