defmodule ChoreRunnerUI.ChoreLiveTest do
  use ExUnit.Case, async: false

  import Phoenix.ConnTest
  import Phoenix.LiveViewTest

  @endpoint ChoreRunner.TestEndpoint

  setup do
    start_supervised!({Phoenix.PubSub, name: ChoreRunner.TestPubSub})
    start_supervised!(ChoreRunner.TestEndpoint)

    start_supervised!(%{
      id: ChoreRunner.Supervisor,
      start: {ChoreRunner.Supervisor, :start_link, [[pubsub: ChoreRunner.TestPubSub]]}
    })

    :ok
  end

  test "renders select defaults, dynamic options, descriptions, and invalid prompt state" do
    {:ok, view, _html} = live(build_conn(), "/chores?chore=FormChore")

    assert has_element?(
             view,
             "#run_chore_chore_attrs_0_static_choice option[selected][value=beta]"
           )

    assert has_element?(view, "#run_chore_chore_attrs_0_dynamic_choice option[value=1]", "One")
    assert has_element?(view, ".chore-form-description", "A hardcoded selection")
    assert has_element?(view, ".chore-instructions summary", "Instructions")

    assert has_element?(
             view,
             ".chore-instructions-content",
             "Choose values to exercise the generated chore form."
           )

    assert has_element?(view, ".chore-run-submit-button[disabled]")
    assert render(view) =~ "not_in_options"
  end

  test "persists non-file form values in the URL and restores them after reload" do
    {:ok, view, _html} = live(build_conn(), "/chores?chore=FormChore&filter=form")

    view
    |> form("form[phx-submit=run_chore]",
      run_chore: %{
        chore: "FormChore",
        chore_attrs: %{
          static_choice: "alpha",
          dynamic_choice: "2",
          count: "7",
          commit?: "true"
        }
      }
    )
    |> render_change()

    path = assert_patch(view)
    query = path |> URI.parse() |> Map.fetch!(:query) |> Plug.Conn.Query.decode()

    assert %{socket: %{assigns: %{browser_managed_checkboxes?: true}}} =
             :sys.get_state(view.pid)

    assert query == %{
             "chore" => "FormChore",
             "filter" => "form",
             "inputs" => %{
               "commit?" => "true",
               "count" => "7",
               "dynamic_choice" => "2",
               "static_choice" => "alpha"
             }
           }

    {:ok, reloaded_view, _html} = live(build_conn(), path)

    assert has_element?(
             reloaded_view,
             "#run_chore_chore_attrs_0_dynamic_choice option[selected][value=2]"
           )

    assert has_element?(
             reloaded_view,
             ~s|input[type=checkbox][name="run_chore[chore_attrs][commit?]"][checked]:not([phx-update])|
           )

    refute has_element?(reloaded_view, ".chore-run-submit-button[disabled]")
  end

  test "shows the selected file name" do
    {:ok, view, _html} = live(build_conn(), "/chores?chore=FormChore")

    upload =
      file_input(view, "form[phx-submit=run_chore]", :upload, [
        %{
          last_modified: 1_725_000_000_000,
          name: "historical-orders.csv",
          content: "order_id,upc\n1,012345678905\n",
          type: "text/csv"
        }
      ])

    render_upload(upload, "historical-orders.csv")

    assert has_element?(view, ".chore-form-file-name", "historical-orders.csv")
  end

  test "persists the chore filter in the URL and restores it after reload" do
    {:ok, view, _html} = live(build_conn(), "/chores?chore=FormChore")

    view
    |> form("form[phx-change=filter_form_changed]",
      filter_chores: %{filter_string: "form"}
    )
    |> render_change()

    path = assert_patch(view)
    query = path |> URI.parse() |> Map.fetch!(:query) |> Plug.Conn.Query.decode()

    assert query == %{"chore" => "FormChore", "filter" => "form"}

    {:ok, reloaded_view, _html} = live(build_conn(), path)

    assert has_element?(reloaded_view, "#filter_chores_filter_string[value=form]")
    assert has_element?(reloaded_view, "#run_chore_chore option[value=FormChore]")
    refute has_element?(reloaded_view, "#run_chore_chore option[value=NonPersistedChore]")
  end

  test "rejects tampered persisted select values" do
    path = "/chores?chore=FormChore&inputs%5Bdynamic_choice%5D=unknown"
    {:ok, view, _html} = live(build_conn(), path)

    assert has_element?(view, ".chore-run-submit-button[disabled]")
    assert render(view) =~ "not_in_options"
  end

  test "keeps changed form values for chores that do not persist inputs in the URL" do
    {:ok, view, _html} = live(build_conn(), "/chores?chore=NonPersistedChore")

    html =
      view
      |> form("form[phx-submit=run_chore]",
        run_chore: %{
          chore: "NonPersistedChore",
          chore_attrs: %{message: "updated"}
        }
      )
      |> render_change()

    assert html =~ ~s(phx-update="ignore")
    assert has_element?(view, "#run_chore_chore_attrs_0_message[phx-update=ignore]")
    assert ChoreRunner.TestChores.NonPersistedChore.persist_inputs_in_url?() == false
  end
end
