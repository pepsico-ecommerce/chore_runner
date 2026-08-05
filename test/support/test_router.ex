defmodule ChoreRunner.TestRouter do
  use Phoenix.Router

  import Phoenix.LiveView.Router

  pipeline :browser do
    plug(:fetch_session)
    plug(:fetch_live_flash)
  end

  scope "/" do
    pipe_through(:browser)

    live_session :chores,
      session: %{
        "otp_app" => :chore_runner,
        "chore_root" => ChoreRunner.TestChores,
        "pubsub" => ChoreRunner.TestPubSub
      } do
      live("/chores", ChoreRunnerUI.ChoreLive, :index)
    end
  end
end
