defmodule ChoreRunner.ChoreCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      defmacro assert_logged(log, opts \\ []) do
        exact_match? = Keyword.get(opts, :exact, false)

        quote do
          assert Process.get(ChoreRunner.Reporter.__process_dict_key__())
                 |> GenServer.call(
                   {:assert_logged,
                    fn
                      {:log, log, _} ->
                        if unquote(exact_match?) do
                          log == unquote(log)
                        else
                          log =~ unquote(log)
                        end

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
