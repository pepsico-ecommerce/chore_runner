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
    html = render(view)
    assert html =~ "Select one of the available options"
    refute html =~ "not_in_options"
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

  test "renders phx-change forms with ids" do
    {:ok, view, _html} = live(build_conn(), "/chores")

    assert has_element?(view, "form#filter_chores[phx-change=filter_form_changed]")
    assert has_element?(view, "form#run_chore[phx-change=form_changed]")
  end

  test "rejects tampered persisted select values" do
    path = "/chores?chore=FormChore&inputs%5Bdynamic_choice%5D=unknown"
    {:ok, view, _html} = live(build_conn(), path)

    assert has_element?(view, ".chore-run-submit-button[disabled]")
    html = render(view)
    assert html =~ "Select one of the available options"
    refute html =~ "not_in_options"
  end

  test "renders a readable message for invalid persisted number values" do
    path = "/chores?chore=FormChore&inputs%5Bcount%5D=abc"
    {:ok, view, _html} = live(build_conn(), path)

    assert has_element?(view, ".chore-run-submit-button[disabled]")

    assert has_element?(
             view,
             "#run_chore_chore_attrs_0_count ~ .chore-form-input-errors-wrapper .alert",
             "Value is invalid"
           )

    refute render(view) =~ ":invalid"
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

  describe "dependent inputs" do
    test "shows each dependent select once the input it depends on is valid" do
      {:ok, view, _html} = live(build_conn(), "/chores?chore=DependentInputsChore")

      assert has_element?(view, "#run_chore_chore_attrs_0_region[phx-update=ignore]")
      refute has_element?(view, "[name=\"run_chore[chore_attrs][city]\"]")
      refute has_element?(view, "[name=\"run_chore[chore_attrs][district]\"]")
      assert has_element?(view, ".chore-run-submit-button[disabled]")

      change_dependent_inputs(view, %{"region" => "north"})

      assert has_element?(
               view,
               "[name=\"run_chore[chore_attrs][city]\"] option[value=oslo]",
               "Oslo"
             )

      assert has_element?(
               view,
               "[name=\"run_chore[chore_attrs][city]\"] option[value=bergen]",
               "Bergen"
             )

      refute has_element?(view, "[name=\"run_chore[chore_attrs][city]\"] option[value=lisbon]")
      assert has_element?(view, "[name=\"run_chore[chore_attrs][city]\"][phx-update=ignore]")
      refute has_element?(view, "[name=\"run_chore[chore_attrs][district]\"]")
      assert has_element?(view, ".chore-run-submit-button[disabled]")

      change_dependent_inputs(view, %{"region" => "north", "city" => "oslo"})

      assert has_element?(
               view,
               "[name=\"run_chore[chore_attrs][district]\"] option[value=frogner]",
               "Frogner"
             )

      change_dependent_inputs(view, %{
        "region" => "north",
        "city" => "oslo",
        "district" => "frogner"
      })

      refute has_element?(view, ".chore-run-submit-button[disabled]")
    end

    test "resets dependents when the input they depend on changes" do
      {:ok, view, _html} = live(build_conn(), "/chores?chore=DependentInputsChore")

      change_dependent_inputs(view, %{"region" => "north"})
      change_dependent_inputs(view, %{"region" => "north", "city" => "oslo"})

      path =
        change_dependent_inputs(view, %{
          "region" => "south",
          "city" => "oslo",
          "district" => "frogner"
        })

      assert has_element?(
               view,
               "[name=\"run_chore[chore_attrs][city]\"] option[value=lisbon]",
               "Lisbon"
             )

      refute has_element?(view, "[name=\"run_chore[chore_attrs][city]\"] option[selected]")
      refute has_element?(view, "[name=\"run_chore[chore_attrs][district]\"]")
      assert has_element?(view, ".chore-run-submit-button[disabled]")

      assert persisted_inputs(path) == %{"region" => "south", "city" => "", "mode" => "summary"}
    end

    test "replaces a dependent input only when its dependency values change" do
      {:ok, view, _html} = live(build_conn(), "/chores?chore=DependentInputsChore")

      change_dependent_inputs(view, %{"region" => "north"})
      city_input_id = city_input_id(view)

      change_dependent_inputs(view, %{"region" => "north", "city" => "oslo"})

      change_dependent_inputs(view, %{"region" => "north", "city" => "oslo", "mode" => "detailed"})

      assert city_input_id(view) == city_input_id

      change_dependent_inputs(view, %{"region" => "south", "city" => "oslo", "mode" => "detailed"})

      refute city_input_id(view) == city_input_id
    end

    test "shows inputs whose visible? function accepts the dependency values" do
      {:ok, view, _html} = live(build_conn(), "/chores?chore=DependentInputsChore")

      refute has_element?(view, "[name=\"run_chore[chore_attrs][guests]\"]")

      change_dependent_inputs(view, %{"mode" => "detailed"})

      assert has_element?(view, "[name=\"run_chore[chore_attrs][guests]\"][value=2]")

      change_dependent_inputs(view, %{"mode" => "detailed", "guests" => "50"})

      assert has_element?(
               view,
               "[name=\"run_chore[chore_attrs][guests]\"] ~ .chore-form-input-errors-wrapper .alert",
               "Choose between 1 and 10 guests"
             )

      path = change_dependent_inputs(view, %{"mode" => "summary", "guests" => "50"})

      refute has_element?(view, "[name=\"run_chore[chore_attrs][guests]\"]")
      refute Map.has_key?(persisted_inputs(path), "guests")
    end

    test "restores a persisted cascade after reload" do
      path =
        "/chores?" <>
          Plug.Conn.Query.encode(%{
            "chore" => "DependentInputsChore",
            "inputs" => %{"region" => "south", "city" => "lisbon", "district" => "belem"}
          })

      {:ok, view, _html} = live(build_conn(), path)

      assert has_element?(
               view,
               "[name=\"run_chore[chore_attrs][city]\"] option[selected][value=lisbon]"
             )

      assert has_element?(
               view,
               "[name=\"run_chore[chore_attrs][district]\"] option[selected][value=belem]"
             )

      refute has_element?(view, ".chore-run-submit-button[disabled]")
    end
  end

  defp change_dependent_inputs(view, chore_attrs) do
    render_change(view, "form_changed", %{
      "run_chore" => %{"chore" => "DependentInputsChore", "chore_attrs" => chore_attrs}
    })

    assert_patch(view)
  end

  defp city_input_id(view) do
    html = view |> element(~s(select[name="run_chore[chore_attrs][city]"])) |> render()
    [_, id] = Regex.run(~r/ id="([^"]+)"/, html)
    id
  end

  defp persisted_inputs(path) do
    path |> URI.parse() |> Map.fetch!(:query) |> Plug.Conn.Query.decode() |> Map.get("inputs")
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
