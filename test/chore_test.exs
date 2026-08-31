defmodule ChoreTest do
  use ExUnit.Case

  alias ChoreRunner.TestChore
  alias ChoreRunner.TestChore2

  defmodule RejectBeforeRunChore do
    use ChoreRunner.Chore

    def inputs do
      [
        selectbox(:buyer_type, [{"Registered", "registered"}]),
        int(:number_of_orders)
      ]
    end

    def validate_inputs(_inputs),
      do: {:error, number_of_orders: ["Registered runs require an even number of Orders."]}

    def run(_inputs), do: raise("run/1 must not be invoked")
  end

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
               logs: [_, _],
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

    test "rejects cross-field errors before starting a reporter or invoking run/1" do
      assert {:error, number_of_orders: ["Registered runs require an even number of Orders."]} =
               ChoreRunner.run_chore(RejectBeforeRunChore, %{
                 buyer_type: "registered",
                 number_of_orders: 3
               })

      assert DynamicSupervisor.which_children(ChoreRunner.ReporterSupervisor) == []
    end
  end

  describe "TestChore.available?/1" do
    test "By default are available" do
      assert TestChore.available?(nil)
    end

    test "Can be made unavailable" do
      refute TestChore2.available?(nil)
    end
  end

  describe "ChoreRunner.list_available_chores/1" do
    test "provides an empty list when sent garbage" do
      assert %{} == ChoreRunner.list_available(nil)
    end

    test "provides the only available test module" do
      assert %{"TestChore" => ChoreRunner.TestChore} ==
               ChoreRunner.list_available(%{
                 "otp_app" => :chore_runner,
                 "chore_root" => ChoreRunner
               })
    end
  end
end
