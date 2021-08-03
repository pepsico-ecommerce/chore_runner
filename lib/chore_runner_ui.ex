defmodule ChoreRunnerUI do
  @moduledoc false
  @pubsub_topic "chore_live_ui:*"
  def view do
    quote do
      use Phoenix.View,
        root: "lib/chore_runner_ui/templates",
        namespace: ChoreRunnerUI

      import Phoenix.Controller,
        only: [get_flash: 1, get_flash: 2, view_module: 1, view_template: 1]

      unquote(view_helpers())
    end
  end

  def live do
    quote do
      use Phoenix.LiveView,
        layout: {ChoreRunnerUI.ChoreView, "live.html"}

      unquote(view_helpers())
    end
  end

  def live_component do
    quote do
      use Phoenix.LiveComponent

      unquote(view_helpers())
    end
  end

  defp view_helpers do
    quote do
      use Phoenix.HTML

      import Phoenix.LiveView.Helpers

      import Phoenix.View
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end

  def pubsub_topic, do: @pubsub_topic
end
