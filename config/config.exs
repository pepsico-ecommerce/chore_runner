import Config

if config_env() == :test do
  config :chore_runner, ChoreRunner.TestEndpoint,
    live_view: [signing_salt: "chore-runner-test"],
    pubsub_server: ChoreRunner.TestPubSub,
    secret_key_base: String.duplicate("a", 64),
    server: false,
    url: [host: "localhost"]
end
