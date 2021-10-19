defmodule ChoreRunnerUI.Components.ChoreModalComponent do
  use Phoenix.LiveComponent
  alias ChoreRunnerUI.ChoreView

  def render(assigns) do
    ChoreView.render("chore_modal.html", assigns)
  end
end
