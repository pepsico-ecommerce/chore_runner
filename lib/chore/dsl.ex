defmodule Chore.DSL do
  @moduledoc """
  Macros which enable the chore DSL
  """
  require Chore.Input
  alias Chore.Input

  def using do
    quote do
      @behaviour Chore
      import Chore.DSL, only: [input: 2, input: 3, validate: 1]
      import Chore.Reporter, only: [report_percent: 1, report_scalar: 1, log: 1]

      Module.register_attribute(__MODULE__, :chore_input, accumulate: true)
      Module.register_attribute(__MODULE__, :chore_input_validators, accumulate: true)

      @before_compile {unquote(__MODULE__), :__before_compile_validate_input__}
      @before_compile unquote(__MODULE__)

      def restriction, do: :self
      defoverridable restriction: 0
    end
  end

  defmacro __before_compile_validate_input__(env) do
    for {key, type} <- Module.get_attribute(env.module, :chore_input, []) do
      validations =
        Module.get_attribute(env.module, :chore_input_validators, [])
        |> Enum.group_by(fn {k, _} -> k end, fn {_, v} -> v end)
        |> Enum.map(fn {k, v} -> {k, List.flatten(v)} end)
        |> Enum.into(%{})
        |> Map.get(key, [])

      quote do
        def __validate_input__(unquote(key), value) do
          with {:ok, value} <- Input.validate(unquote(type), value),
               :ok <- __do_other_validations__(unquote(key), value) do
            {:ok, {unquote(key), value}}
          else
            {:error, reason} -> {:error, {reason, value}}
          end
        end

        defp __do_other_validations__(unquote(key), value) do
          unquote(validations)
          |> Enum.reduce({:ok, []}, fn
            validation_function, {status, errors} ->
              case validation_function.(value) do
                :ok -> {status, errors}
                {:error, reason} -> {:error, [reason | errors]}
              end
          end)
          |> case do
            {:ok, _} -> :ok
            error -> error
          end
        end
      end
    end
  end

  defmacro __before_compile__(_) do
    quote do
      def validate_input(input) do
        Enum.reduce(input, {true, []}, fn {key, val}, {valid?, errors} ->
          case __MODULE__.__validate_input__(key, val) do
            {:ok, _} ->
              {valid?, errors}

            {:error, reason} ->
              {false, [{key, reason} | errors]}
          end
        end)
        |> case do
          {true, _} -> {:ok, input}
          {false, errors} -> {:error, errors}
        end
      end

      def __validate_input__(key, _) do
        {:error, {:unexpected_key, key}}
      end

      def inputs, do: @chore_input
    end
  end

  defmacro input(key, type, ast \\ [{:do, []}])

  defmacro input(key, type, do: ast) when Input.valid_type(type) do
    validators = get_validators(ast)

    quote do
      unquote(ast)

      Module.put_attribute(
        __MODULE__,
        :chore_input_validators,
        {unquote(key), unquote(validators)}
      )

      Module.put_attribute(__MODULE__, :chore_input, {unquote(key), unquote(type)})
    end
  end

  defmacro input(key, type, _ast) when not Input.valid_type(type) do
    """
    Input #{inspect(key)} has invalid type (#{inspect(type)}).
    Type must be one of the following valid types:
    #{Input.types() |> Enum.map(&inspect/1) |> Enum.join(", ")}
    """
    |> raise()
  end

  defmacro input(key, _type, _ast) do
    """
    Input #{inspect(key)} got unexpected third argument, expected a `do ... end` block
    """
    |> raise()
  end

  # The validation function is walked out of `input`
  defmacro validate({:&, attrs, [{:/, _, [_, n]}]}) do
    if n == 1, do: [], else: validator_error(attrs)
  end

  defmacro validate(ast) do
    with {func, _} <- Code.eval_quoted(ast),
         true <- is_function(func),
         {:arity, 1} <- Function.info(func, :arity) do
      []
    else
      _ ->
        validator_error([])
    end
  end

  defp get_validators(ast) do
    {_, validators} =
      Macro.traverse(
        ast,
        [],
        fn
          {:validate, _attrs, [validate_func_ast]}, acc ->
            {[], [validate_func_ast | acc]}

          {:validate, attrs, _}, _ ->
            validator_error(attrs)

          {:__block__, _, _} = tree, acc ->
            {tree, acc}

          _, acc ->
            {[], acc}
        end,
        fn tree, acc -> {tree, acc} end
      )

    validators
    |> Enum.reverse()
    |> Macro.escape()
  end

  defp validator_error(attrs) do
    line_msg = if n = Keyword.get(attrs, :line, nil), do: "on line #{n} ", else: ""

    """
    The macro `validate` #{line_msg}expects a single argument consisting
    of a 1 arity function which returns either :ok or an {:error, reason} tuple.
    """
    |> raise()
  end
end
