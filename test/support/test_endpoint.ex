defmodule ChoreRunner.TestEndpoint do
  use Phoenix.Endpoint, otp_app: :chore_runner

  socket("/live", Phoenix.LiveView.Socket)

  plug(Plug.Session,
    store: :cookie,
    key: "_chore_runner_test",
    signing_salt: "chore-runner-session"
  )

  plug(ChoreRunner.TestRouter)
end
