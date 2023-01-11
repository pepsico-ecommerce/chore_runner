# ChoreRunner
An Elixir library for writing and running code chores.

- [Motivation](#motivation)
- [Installation](#installation)
- [Writing a Chore](#writing-a-chore)
- [Chore Reporting](#chore-reporting)
- [Telemetry](#telemetry)
- [Contribution](#contribution)
## Motivation
### What is a "Chore"?
A "Chore" can really be anything, but most commonly it is just some infrequently, manually run code which achieve a business or development goal.

For example: updating a config value in a database that does not yet have a UI (perhaps due to time constraints) is a great use for a chore. A chore could be created that accepts the desired value and runs the update query.

### What problem does ChoreRunner solve?
The primary fast alternative to extensive development for some infrequent business need tends to be a direct prod-shell or prod-db connection, which is inherently insecure and dangerous.
Many fast-moving startups or companies are ok with this access for developers, and that's fine. But many companies have regulations that they must follow, or do not want to take the risk of a developer mistake while working in these environments.

ChoreRunner allows the rapid creation, testing, and reviewing of code chores, along with a bundled UI for running them that accepts a variety of input types,
with the goal of finding a "sweet spot" of safety and speed when solving such problems.

### Shells vs Chores
- Remote shells skip testing and review processes that could detect issues with the code being executed. Chores are easily tested and reviewed, and tested/reviewed code is safer than untested and unreviewed code.
- Remote-shell access is a common security audit issue. To comply with security requirements such as PCI-DSS, they might need to be restricted. Chores are a normal part of your app, with controlled behavior like any other admin page, and will not flag most security audits (depending on how you use them).
- Two developers could unwittingly step on each other's toes if using remote shells in the same app simultaneously. Chores have built-in protections for this.
- A common reason for using shells is the lack of developer bandwidth to create specific admin functionality for an uncommon task. ChoreRunner ships with a LiveView UI that generates input forms automatically, and lets you track chore progress.
## Installation
Add `chore_runner` to your deps.
```elixir
{:chore_runner, "~> 0.1.3"}
```
Add `ChoreRunner` to your supervision tree, after your app's `PubSub`:
```elixir
children = [
  {Phoenix.PubSub, [name: MyApp.PubSub]},
  {ChoreRunner, [pubsub: MyApp.PubSub]},
]
```
Decide your app's chore namespace and maybe write an example chore:
```elixir
defmodule MyApp.Chores.MyFirstChore do
  use ChoreRunner.Chore
  # Chore namespace is MyApp.Chores
  def run(_), do: :ok
end
```
Add the UI to your router, passing `otp_app`, `chore_root`, and `pubsub` keys in the session:
```elixir
@chore_session %{"otp_app" => :my_app, "chore_root" => MyApp.Chores, "pubsub" => MyApp.PubSub}
scope "/" do
  pipe_through :browser

  live_session :chores, session: @chore_session do
    live "/chores", ChoreRunnerUI.ChoreLive, :index
  end
end
```
### NOTE
Your Phoenix app must be LiveView-enabled for the UI to work properly.

You can now visit your UI at the route specified.

## Writing a Chore
The most basic chore module looks like this
```elixir
defmodule MyApp.Chores.BasicChore do
  use ChoreRunner.Chore

  def run(_) do
  # ...
  end
end
```

Besides `run/1`, there are two other callbacks that you can implement

### `input/0`

```elixir
defmodule MyApp.Chores.BasicChore do
  use ChoreRunner.Chore

  def input do
    [
      string(:my_string),
      int(:my_int),
      float(:my_float),
      bool(:my_bool),
      file(:my_file),
    ]
  end

  def run(_inputs) do
  # ...
  end
end
```

The input callback lets you define expected inputs to the chore using input functions imported from ChoreRunner.Input. Input not defined in the callback will be discarded when passed to a chore through `ChoreRunner.run_chore/2`. The 5 supported input types are:
- string
- int
- float
- bool
- file

Input functions also accept an optional keyword list of options as a second argument. The supported keys are:
- :description — a description of an input
- :validators — a list of functions, either captured or anonymous, that can be used to transform and validate any provided input.
  ```elixir
  def input do
    [
      string(:name, validators: [&check_length/1, & {:ok, String.capitalize(&1)}]),
    ]
  end

  defp check_length(string) do
    if String.length(string) < 3 do
      {:error, "Must be 3 or more characters in lenth"}
    else
      :ok
    end
  end
  ```
  Each input type has a default validator that are always run, which do basic type validation.
### `restriction/0`
The restriction callback configures each chore's concurrency restriction. Concurrency restriction potentially prevents a chore from running depending on what chores are currently running. This includes chores running on other nodes. It supports 3 valid return values:
- `def restriction, do: :none`

  The chore has no restrictions. Multiple of this chore can be run similtaneously.
- `def restriction, do: :self`

  Only one of this specific chore is allowed to run at a time.
- `def restriction, do: :global`

  Only one :global chore can run at a time, even between different chores. This does not prevent other non-global chores from running.

### `run/1`
The meat of your chore will reside in the `run/1` callback. When you run a chore through the UI, that calls `ChoreRunner.run_chore/2`, which eventually calls out to your `run/1` callback. It accepts an atom-keyed map of expected input, defined by the `input` callback. Input presence in the map is not garaunteed, but you are garaunteed to only receive input specified in the callback. Any return value is is stored in the chore struct via the reporter, broadcasted on the pubsub, and also directly passed to the configured chore resolution handler on chore completion.

## Chore Reporting
`use ChoreRunner.Chore` imports the following functions for use in the `run/1` callback:
- `log(message)`

  Logs a timestamped string
- `set_counter(counter_key, counter_value)`

  Sets the specified counter to the provided value
- `inc_counter(counter_key, value_to_increment_by)`

  Increments the specified counter by the provided value. If the value does not exist, the value defaults to 0, then is incremented.

These functions work in both the main chore process, and certain spawned processes such as via `Task.async_stream` for parellelization. Attempting to call these functions outside of those conditions will result in an exception.

## Telemetry
The following telemetry events are sent from the `ChoreRunner.Reporter`
- `[:chore_runner, :reporter, :chore_failed]`
  - Emitted when chore has failed.
  - Sends `%{state: chore_state, error_reason: reason}`.
- `[:chore_runner, :reporter, :chore_finished]`
  - Emitted when chore has finished.
  - Sends `%Chore{result: nil}` where the result is set to nil to avoid sending large results through telemetry. 
- `[:chore_runner, :reporter, :init]`
  - Emitted when the reporter is started.
  - Sends `%{chore: chore, opts: init_opts}`.
- `[:chore_runner, :reporter, :log]`
  - Emitted when a log is added.
  - Sends `%{state: chore_state}`.
- `[:chore_runner, :reporter, :start_chore]`
  - Emitted when a chore is started.
  - Sends `%{state: chore_state}`.
- `[:chore_runner, :reporter, :stop_chore]`
  - Emitted when a chore is stopped.
  - Sends `%{status: status, state: chore_state}` where state is `:ok | :error`.
- `[:chore_runner, :reporter, :update_counter]`
  - Emitted when counter is updated.
  - Sends `%{state: chore_state}`.

## Contribution

Unfortunately, we cannot accept pull requests at this time. However, we will adress any and all issues opened related to bugs or ideas/features.