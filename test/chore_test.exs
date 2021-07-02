defmodule ChoreTest do
  use ExUnit.Case
  alias Chore.TestChore

  describe "run_chore/3" do
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

  describe "run_chore/3 while distributed" do
    setup do
      node = :"secondary@127.0.0.1"
      Chore.TestCluster.spawn([node])
      {:ok, %{node: node}}
    end

    test "Does not allow a chore to run at the same time on separate nodes", %{node: node} do
      input = %{
        my_string: "string",
        my_float: 4.2,
        my_file: "test/support/test_file.txt",
        sleep_length: 5000,
        sleep?: true
      }

      :rpc.async_call(node, Chore, :run_chore, [TestChore, input, 1000])

      assert {:error, :asdf} = Chore.run_chore(TestChore, input, 6000)
    end
  end
end
