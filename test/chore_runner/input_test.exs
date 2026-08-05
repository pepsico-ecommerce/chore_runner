defmodule ChoreRunner.InputTest do
  use ExUnit.Case, async: true

  alias ChoreRunner.Input

  defmodule DefaultChore do
    use ChoreRunner.Chore

    def inputs do
      [int(:batch_size, default: 25)]
    end

    def run(inputs), do: {:ok, inputs}
  end

  test "keeps the existing input tuple API and two-argument validation behavior" do
    assert Input.string(:message, description: "A message") ==
             {:string, :message, description: "A message"}

    assert Input.int(:count) == {:int, :count, []}
    assert Input.float(:ratio) == {:float, :ratio, []}
    assert Input.file(:upload) == {:file, :upload, []}
    assert Input.bool(:commit?) == {:bool, :commit?, []}

    assert Input.validate_field(:string, 42) == {:ok, "42"}
    assert Input.validate_field(:int, "42") == {:ok, 42}
    assert Input.validate_field(:float, "4.2") == {:ok, 4.2}
    assert Input.validate_field(:bool, "true") == {:ok, true}
  end

  describe "selectbox/3" do
    test "validates static Phoenix select options and restores declared value types" do
      options = [
        "String value",
        {"Integer value", 42},
        {"Grouped", [{"Atom value", :atom_value}]},
        [key: "Rich option", value: 4.2],
        :hr
      ]

      input = Input.selectbox(:selection, options, description: "Choose one")

      assert {:select, :selection, opts} = input
      assert Input.select_options(opts) == options
      assert {:ok, "String value"} = Input.validate_field(:select, "String value", opts)
      assert {:ok, 42} = Input.validate_field(:select, "42", opts)
      assert {:ok, :atom_value} = Input.validate_field(:select, "atom_value", opts)
      assert {:ok, 4.2} = Input.validate_field(:select, "4.2", opts)
      assert {:error, :not_in_options} = Input.validate_field(:select, "unknown", opts)
    end

    test "resolves a zero-arity options provider for rendering and validation" do
      parent = self()

      provider = fn ->
        send(parent, :provider_called)
        [{"Enabled", true}, {"Disabled", false}]
      end

      {:select, :status, opts} = Input.selectbox(:status, provider)

      assert Input.select_options(opts) == [{"Enabled", true}, {"Disabled", false}]
      assert_receive :provider_called
      assert {:ok, true} = Input.validate_field(:select, "true", opts)
      assert_receive :provider_called
    end

    test "rejects ambiguous values with the same HTML representation" do
      {:select, :selection, opts} =
        Input.selectbox(:selection, [{"String", "1"}, {"Integer", 1}])

      assert_raise ArgumentError, ~r/must have unique HTML representations/, fn ->
        Input.validate_field(:select, "1", opts)
      end
    end

    test "rejects malformed provider results" do
      {:select, :selection, opts} = Input.selectbox(:selection, fn -> :invalid end)

      assert_raise ArgumentError, ~r/select options must be a list, map/, fn ->
        Input.select_options(opts)
      end
    end
  end

  test "defaults are validated and supplied when a caller omits the input" do
    assert {:ok, %{batch_size: 25}} = DefaultChore.validate_input(%{})
    assert {:ok, %{batch_size: 10}} = DefaultChore.validate_input(%{"batch_size" => "10"})
  end
end
