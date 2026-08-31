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

  test "shows cross-field errors and clears them when either dependent input is corrected" do
    {:ok, view, _html} = live(build_conn(), "/chores?chore=CrossFieldValidationChore")

    error = "Registered runs require an even number of Orders."

    assert has_element?(
             view,
             "#run_chore_chore_attrs_0_number_of_orders ~ .chore-form-input-errors-wrapper .alert",
             error
           )

    error_html =
      view
      |> element(
        "#run_chore_chore_attrs_0_number_of_orders ~ .chore-form-input-errors-wrapper .alert"
      )
      |> render()

    assert error_html =~ ">#{error}</p>"
    refute error_html =~ ~s(>"#{error}"</p>)

    assert has_element?(view, ".chore-run-submit-button[disabled]")

    html =
      view
      |> form("form[phx-submit=run_chore]",
        run_chore: %{
          chore: "CrossFieldValidationChore",
          chore_attrs: %{buyer_type: "registered", number_of_orders: "4"}
        }
      )
      |> render_change()

    refute html =~ error
    refute has_element?(view, ".chore-run-submit-button[disabled]")

    view
    |> form("form[phx-submit=run_chore]",
      run_chore: %{
        chore: "CrossFieldValidationChore",
        chore_attrs: %{buyer_type: "registered", number_of_orders: "3"}
      }
    )
    |> render_change()

    assert has_element?(view, ".chore-run-submit-button[disabled]")

    html =
      view
      |> form("form[phx-submit=run_chore]",
        run_chore: %{
          chore: "CrossFieldValidationChore",
          chore_attrs: %{buyer_type: "guest", number_of_orders: "3"}
        }
      )
      |> render_change()

    refute html =~ error
    refute has_element?(view, ".chore-run-submit-button[disabled]")
  end

  test "preserves other persisted values across partial cross-field form changes" do
    {:ok, view, _html} =
      live(build_conn(), "/chores?chore=PersistedCrossFieldValidationChore")

    render_change(view, "form_changed", %{
      "run_chore" => %{
        "chore" => "PersistedCrossFieldValidationChore",
        "chore_attrs" => %{"generation_key" => "batch_one"}
      }
    })

    path = assert_patch(view)

    assert_persisted_values(view, path, %{
      "batch_size" => "500",
      "buyer_type" => "registered",
      "generation_key" => "batch_one",
      "number_of_orders" => "4"
    })

    render_change(view, "form_changed", %{
      "run_chore" => %{
        "chore" => "PersistedCrossFieldValidationChore",
        "chore_attrs" => %{"number_of_orders" => "3"}
      }
    })

    path = assert_patch(view)

    assert_persisted_values(view, path, %{
      "batch_size" => "500",
      "buyer_type" => "registered",
      "generation_key" => "batch_one",
      "number_of_orders" => "3"
    })

    assert has_element?(view, ".chore-run-submit-button[disabled]")

    render_change(view, "form_changed", %{
      "run_chore" => %{
        "chore" => "PersistedCrossFieldValidationChore",
        "chore_attrs" => %{"generation_key" => "batch_two"}
      }
    })

    path = assert_patch(view)

    assert_persisted_values(view, path, %{
      "batch_size" => "500",
      "buyer_type" => "registered",
      "generation_key" => "batch_two",
      "number_of_orders" => "3"
    })

    assert has_element?(view, ".chore-run-submit-button[disabled]")

    render_change(view, "form_changed", %{
      "run_chore" => %{
        "chore" => "PersistedCrossFieldValidationChore",
        "chore_attrs" => %{"batch_size" => "250"}
      }
    })

    path = assert_patch(view)

    assert_persisted_values(view, path, %{
      "batch_size" => "250",
      "buyer_type" => "registered",
      "generation_key" => "batch_two",
      "number_of_orders" => "3"
    })

    render_change(view, "form_changed", %{
      "run_chore" => %{
        "chore" => "PersistedCrossFieldValidationChore",
        "chore_attrs" => %{"buyer_type" => "guest"}
      }
    })

    path = assert_patch(view)

    assert_persisted_values(view, path, %{
      "batch_size" => "250",
      "buyer_type" => "guest",
      "generation_key" => "batch_two",
      "number_of_orders" => "3"
    })

    refute has_element?(view, ".chore-run-submit-button[disabled]")
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

  defp assert_persisted_values(view, path, expected) do
    query = path |> URI.parse() |> Map.fetch!(:query) |> Plug.Conn.Query.decode()

    assert query["inputs"] == expected

    assert has_element?(
             view,
             "#run_chore_chore_attrs_0_buyer_type[phx-update=ignore]"
           )

    for field <- ~w(batch_size generation_key number_of_orders) do
      assert has_element?(
               view,
               "#run_chore_chore_attrs_0_#{field}[phx-update=ignore]"
             )
    end
  end
end
