defmodule ChoreRunnerUI.ChoreFormTest do
  use ExUnit.Case, async: true

  alias ChoreRunnerUI.ChoreForm

  test "combines prompts, defaults, and declared persisted values" do
    inputs = [
      {:select, :workspace, [options: ["primary"], prompt: "Choose a workspace"]},
      {:int, :batch_size, [default: 5_000]},
      {:bool, :commit?, [default: false]},
      {:file, :upload, []}
    ]

    persisted = %{
      "workspace" => "primary",
      "batch_size" => "2500",
      "commit?" => "true",
      "upload" => "/tmp/not-accepted",
      "undeclared" => "ignored"
    }

    assert ChoreForm.initial_values(inputs, persisted) == %{
             "workspace" => "primary",
             "batch_size" => "2500",
             "commit?" => "true"
           }
  end

  test "keeps only declared non-file inputs for URL persistence" do
    inputs = [
      {:string, :name, []},
      {:file, :upload, []}
    ]

    values = %{"name" => "safe", "upload" => "/tmp/file", "other" => "ignored"}

    assert ChoreForm.persistable_values(inputs, values) == %{"name" => "safe"}
  end

  test "resets transitive dependents of a changed input to their initial values" do
    inputs = [
      {:select, :region, [options: ["north", "south"], prompt: "Choose a region"]},
      {:select, :city, [options: &Function.identity/1, prompt: "Choose", depends_on: [:region]]},
      {:string, :street, [depends_on: [:city]]},
      {:int, :guests, [default: 2, depends_on: [:region]]},
      {:string, :note, []}
    ]

    previous = %{
      "region" => "north",
      "city" => "oslo",
      "street" => "Main",
      "guests" => "4",
      "note" => "kept"
    }

    assert ChoreForm.reset_dependents(inputs, previous, %{previous | "region" => "south"}) == %{
             "region" => "south",
             "city" => "",
             "guests" => 2,
             "note" => "kept"
           }

    assert ChoreForm.reset_dependents(inputs, previous, %{previous | "note" => "changed"}) ==
             %{previous | "note" => "changed"}
  end
end
