defmodule ChoreTest do
  use ExUnit.Case
  alias Chore.TestChore

  describe "run/3" do
    test "Runs a chore with valid inputs" do
      assert {:ok, result} =
               Chore.run_chore(
                 TestChore,
                 %{
                   my_string: "string",
                   my_float: 4.2,
                   my_file: "test/support/test_file.txt",
                   sleep_length: 0,
                   sleep?: false
                 },
                 1000
               )

      assert result.my_string == "string"
      assert result.my_float == 4.2
      assert result.my_file == "test/support/test_file.txt"
      assert result.my_file_value == "I am a test file"
      assert result.sleep_length == 0
      assert result.sleep? === false
    end

    test "Rejects a chore with invalid inputs" do
      assert {:error, errors} =
               Chore.run_chore(
                 TestChore,
                 %{
                   my_string: :atom,
                   my_float: 1,
                   my_file: nil,
                   sleep_length: 4.3,
                   sleep?: "false"
                 },
                 1000
               )

      assert Keyword.get(errors, :sleep_length) == {:invalid, 4.3}
      assert Keyword.get(errors, :sleep?) == {:invalid, "false"}
      assert Keyword.get(errors, :my_string) == {:invalid, :atom}
      assert Keyword.get(errors, :my_float) == {:invalid, 1}
      assert Keyword.get(errors, :my_file) == {:invalid, nil}
    end

    test "Rejects a chore with a nonexistant file" do
      assert {:error, errors} =
               Chore.run_chore(
                 TestChore,
                 %{
                   my_string: "string",
                   my_float: 4.2,
                   my_file: "test/support/bad_file.txt",
                   sleep_length: 0,
                   sleep?: false
                 },
                 1000
               )

      assert Keyword.get(errors, :my_file) == {:does_not_exist, "test/support/bad_file.txt"}
    end
  end
end
