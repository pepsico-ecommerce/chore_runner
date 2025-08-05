defmodule ChoreRunner.DSL do
  @moduledoc """
  Macros which enable the chore DSL
  """

  def parse_result_handler(nil), do: & &1

  def parse_result_handler({:fn, _, _} = fun) do
    Macro.escape(fun)
  end

  def parse_result_handler(handler) when is_function(handler, 1) do
    handler
  end

  def parse_result_handler({m, f, a}) do
    if function_exported?(m, f, a) do
      fn chore -> apply(m, f, [chore]) end
    else
      raise "Function not exported for {#{m}, #{f}, #{a}}"
    end
  end

  def parse_result_handler(handler) do
    raise "result_handler must be an anonymous function, function capture, MFA of a single arity function, or nil. Got: #{inspect(handler)}"
  end

  def using(opts) do
    quote do
      alias ChoreRunner.Chore
      @behaviour Chore

      import ChoreRunner.Reporter,
        only: [
          report_failed: 1,
          report_failed: 2,
          log: 1,
          log: 2,
          set_counter: 2,
          set_counter: 3,
          inc_counter: 2,
          inc_counter: 3,
          get_reporter: 0
        ]

      import ChoreRunner.Input,
        only: [
          string: 2,
          int: 2,
          float: 2,
          file: 2,
          bool: 2,
          string: 1,
          int: 1,
          float: 1,
          file: 1,
          bool: 1
        ]

      def create_download(filename, opts) do
        opts = Keyword.put_new_lazy(opts, :chore_id, fn -> Process.get(:chore_id) end)

        filename
        |> ChoreRunner.Downloads.create_download(opts)
        |> tap(fn
          {:ok, download} ->
            ChoreRunner.Reporter.register_download(download)

            case Process.get(:chore_pubsub) do
              nil ->
                :noop

              pubsub ->
                Phoenix.PubSub.broadcast(
                  pubsub,
                  ChoreRunner.downloads_pubsub_topic(),
                  :downloads_updated
                )
            end

          _ ->
            :noop
        end)
      end

      def restriction, do: :self
      def inputs, do: []

      def validate_input(input),
        do: Chore.validate_input(%Chore{mod: __MODULE__}, input)

      def result_handler(chore) do
        result_handler = unquote(__MODULE__).parse_result_handler(unquote(opts)[:result_handler])
        result_handler.(chore)
      end

      def available?(_opts) do
        true
      end

      defoverridable inputs: 0, restriction: 0, result_handler: 1, available?: 1
    end
  end
end
