defmodule ChoreRunner.ChoreCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      defmacro assert_logged(log, opts \\ []) do
        quote do
          logs =
            ChoreRunner.Reporter.__process_dict_key__()
            |> Process.get()
            |> GenServer.call(:logs)

          assert logs =~ unquote(log)
        end
      end
    end
  end

  setup do
    pid = start_supervised!(ChoreRunner.ChoreCase.TestReporter)
    Process.put(ChoreRunner.Reporter.__process_dict_key__(), pid)

    :ok
  end
end
