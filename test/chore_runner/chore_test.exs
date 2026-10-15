defmodule ChoreRunner.ChoreTest do
  use ExUnit.Case, async: true

  alias ChoreRunner.Chore

  defmodule ExplicitInstructionsChore do
    @moduledoc "Module documentation"

    use ChoreRunner.Chore

    def instructions, do: "Explicit instructions"
    def run(inputs), do: {:ok, inputs}
  end

  defmodule ModuleDocChore do
    @moduledoc "Module documentation"

    use ChoreRunner.Chore

    def run(inputs), do: {:ok, inputs}
  end

  defmodule DefaultValidationChore do
    use ChoreRunner.Chore

    def inputs, do: [int(:count, default: 2)]
    def run(inputs), do: {:ok, inputs}
  end

  defmodule NormalizedInputChore do
    use ChoreRunner.Chore

    def inputs do
      [
        selectbox(:buyer_type, [{"Registered", :registered}]),
        int(:number_of_orders, default: 2)
      ]
    end

    def validate_inputs(%{buyer_type: :registered, number_of_orders: number_of_orders} = inputs)
        when is_integer(number_of_orders),
        do: {:ok, inputs}

    def validate_inputs(_inputs), do: {:error, number_of_orders: ["inputs were not normalized"]}

    def run(inputs), do: {:ok, inputs}
  end

  defmodule MalformedValidationChore do
    use ChoreRunner.Chore

    def inputs, do: [int(:count)]
    def validate_inputs(_inputs), do: :ok
    def run(inputs), do: {:ok, inputs}
  end

  defmodule UnknownErrorFieldChore do
    use ChoreRunner.Chore

    def inputs, do: [int(:count)]
    def validate_inputs(_inputs), do: {:error, other_count: ["is invalid"]}
    def run(inputs), do: {:ok, inputs}
  end

  defmodule ForwardDependencyChore do
    use ChoreRunner.Chore

    def inputs, do: [string(:city, depends_on: [:region]), string(:region)]
    def run(inputs), do: {:ok, inputs}
  end

  defmodule FileDependencyChore do
    use ChoreRunner.Chore

    def inputs, do: [file(:upload), string(:sheet, depends_on: [:upload])]
    def run(inputs), do: {:ok, inputs}
  end

  defmodule UndeclaredProviderDependencyChore do
    use ChoreRunner.Chore

    def inputs, do: [selectbox(:city, fn %{region: _region} -> [] end)]
    def run(inputs), do: {:ok, inputs}
  end

  defmodule UndeclaredVisibilityDependencyChore do
    use ChoreRunner.Chore

    def inputs, do: [int(:guests, visible?: fn _dependency_values -> true end)]
    def run(inputs), do: {:ok, inputs}
  end

  test "prefers explicit instructions" do
    assert Chore.instructions_for(ExplicitInstructionsChore) == "Explicit instructions"
  end

  test "falls back to module documentation" do
    assert ModuleDocChore.instructions() == "Module documentation"
    assert Chore.instructions_for(ModuleDocChore) == "Module documentation"
  end

  test "provides a default cross-field validator that returns inputs unchanged" do
    inputs = %{count: 2}

    assert DefaultValidationChore.validate_inputs(inputs) == {:ok, inputs}
    assert DefaultValidationChore.validate_input(%{}) == {:ok, inputs}
  end

  test "passes defaulted, cast, atom-keyed values to cross-field validation" do
    assert NormalizedInputChore.validate_input(%{"buyer_type" => "registered"}) ==
             {:ok, %{buyer_type: :registered, number_of_orders: 2}}
  end

  test "returns cross-field errors in the existing field error structure" do
    assert ChoreRunner.TestChores.CrossFieldValidationChore.validate_input(%{
             "buyer_type" => "registered",
             "number_of_orders" => "3"
           }) ==
             {:error, number_of_orders: ["Registered runs require an even number of Orders."]}
  end

  test "raises clearly when cross-field validation returns a malformed response" do
    assert_raise ArgumentError,
                 ~r/MalformedValidationChore.validate_inputs\/1 must return \{:ok, map\}/,
                 fn ->
                   MalformedValidationChore.validate_input(%{count: 2})
                 end
  end

  test "raises clearly when cross-field errors reference undeclared inputs" do
    assert_raise ArgumentError,
                 ~r/UnknownErrorFieldChore.validate_inputs\/1 returned errors for undeclared inputs: \[:other_count\]/,
                 fn ->
                   UnknownErrorFieldChore.validate_input(%{count: 2})
                 end
  end

  describe "dependent inputs" do
    alias ChoreRunner.TestChores.DependentInputsChore

    test "leaves dependents inactive until the inputs they depend on are valid" do
      resolved = Chore.resolve_inputs(%Chore{mod: DependentInputsChore}, %{"region" => ""})

      assert active_input_names(resolved) == [:region, :mode]
      assert resolved.errors == [region: [:not_in_options]]
      refute Map.has_key?(resolved.select_options, :city)
    end

    test "resolves select options from the validated values of earlier inputs" do
      resolved =
        Chore.resolve_inputs(%Chore{mod: DependentInputsChore}, %{
          "region" => "south",
          "city" => "lisbon"
        })

      assert active_input_names(resolved) == [:region, :city, :district, :mode]
      assert resolved.select_options.city == [{"Lisbon", "lisbon"}, {"Porto", "porto"}]
      assert resolved.select_options.district == [{"Alfama", "alfama"}, {"Belém", "belem"}]
    end

    test "rejects a dependent value that belongs to a different dependency value" do
      assert DependentInputsChore.validate_input(%{
               "region" => "north",
               "city" => "lisbon",
               "district" => "alfama"
             }) == {:error, city: [:not_in_options]}
    end

    test "drops values of inactive inputs from the validated inputs" do
      assert DependentInputsChore.validate_input(%{
               "region" => "north",
               "city" => "oslo",
               "district" => "frogner",
               "guests" => "50"
             }) ==
               {:ok, %{region: "north", city: "oslo", district: "frogner", mode: "summary"}}
    end

    test "validates inputs made visible by their visible? function" do
      inputs = %{
        "region" => "north",
        "city" => "bergen",
        "district" => "sentrum",
        "mode" => "detailed"
      }

      assert DependentInputsChore.validate_input(inputs) ==
               {:ok,
                %{
                  region: "north",
                  city: "bergen",
                  district: "sentrum",
                  mode: "detailed",
                  guests: 2
                }}

      assert DependentInputsChore.validate_input(Map.put(inputs, "guests", "50")) ==
               {:error, guests: ["Choose between 1 and 10 guests"]}
    end

    test "rejects dependent values when running the chore" do
      assert ChoreRunner.run_chore(DependentInputsChore, %{
               "region" => "north",
               "city" => "porto",
               "district" => "ribeira"
             }) == {:error, city: [:not_in_options]}
    end

    test "raises when an input depends on an input declared after it" do
      assert_raise ArgumentError,
                   ~r/:city depends on :region, which must be an input declared before it/,
                   fn ->
                     ForwardDependencyChore.validate_input(%{})
                   end
    end

    test "raises when an input depends on a file input" do
      assert_raise ArgumentError, ~r/:sheet cannot depend on file input :upload/, fn ->
        FileDependencyChore.validate_input(%{})
      end
    end

    test "raises when a dependency-aware option provider declares no dependencies" do
      assert_raise ArgumentError,
                   ~r/:city has a select options provider that expects dependency values/,
                   fn ->
                     UndeclaredProviderDependencyChore.validate_input(%{})
                   end
    end

    test "raises when visible? is declared without dependencies" do
      assert_raise ArgumentError, ~r/:guests declares :visible\? without :depends_on/, fn ->
        UndeclaredVisibilityDependencyChore.validate_input(%{})
      end
    end
  end

  defp active_input_names(resolved),
    do: Enum.map(resolved.active_inputs, fn {_type, name, _opts} -> name end)
end
