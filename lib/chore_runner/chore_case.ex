defmodule ChoreRunner.ChoreCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      defmacro assert_logged(log) do
        quote do
          assert Process.get(ChoreRunner.Reporter.__process_dict_key__())
                 |> GenServer.call(
                   {:assert_logged,
                    fn
                      {:log, log, _} ->
                        log == unquote(log)

                      _ ->
                        false
                    end}
                 )
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