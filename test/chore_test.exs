defmodule ChoreTest do
  use ExUnit.Case
  alias ChoreRunner.TestChore

  setup do
    pid =
      start_supervised!(%{
        id: ChoreRunner.Supervisor,
        start: {ChoreRunner.Supervisor, :start_link, [[]]}
      })

    {:ok, reporter_supervisor: pid}
  end

  describe "run_chore/3" do
    test "Runs a chore with valid inputs" do
      ref = make_ref()
      pid = self()

      assert {:ok, _chore} =
               ChoreRunner.run_chore(
                 TestChore,
                 %{
                   my_string: "string",
                   my_float: 4.2,
                   my_file: "test/support/test_file.txt",
                   sleep_length: 0,
                   sleep?: false
                 },
                 result_handler: fn chore ->
                   send(pid, {ref, chore})
                 end,
                 extra_data: %{foo: :bar}
               )

      assert_receive {^ref, chore}

      assert %{
               extra_data: %{foo: :bar},
               inputs: %{
                 my_file: "test/support/test_file.txt",
                 my_float: 4.2,
                 my_string: "string",
                 sleep?: false,
                 sleep_length: 0
               },
               logs: [],
               mod: ChoreRunner.TestChore,
               result:
                 {:ok,
                  %{
                    my_file: "test/support/test_file.txt",
                    my_file_value: "I am a test file",
                    my_float: 4.2,
                    my_string: "string",
                    sleep?: false,
                    sleep_length: 0
                  }}
             } = chore
    end

    test "Rejects a chore with invalid inputs" do
      assert {:error, errors} =
               ChoreRunner.run_chore(
                 TestChore,
                 %{
                   my_string: :atom,
                   my_float: 1,
                   my_file: nil,
                   sleep_length: 4.3,
                   sleep?: "false"
                 }
               )

      assert Keyword.get(errors, :sleep_length) == [:invalid]
    end

    test "Rejects a chore with a nonexistant file" do
      assert {:error, errors} =
               ChoreRunner.run_chore(
                 TestChore,
                 %{
                   my_string: "string",
                   my_float: 4.2,
                   my_file: "test/support/bad_file.txt",
                   sleep_length: 0,
                   sleep?: false
                 }
               )

      assert Keyword.get(errors, :my_file) == [:does_not_exist]
    end
  end
end
