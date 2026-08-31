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
end
