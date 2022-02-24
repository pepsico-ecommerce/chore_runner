defmodule ChoreRunner.Input do
  @valid_types ~w(string int float file bool select)a

  @type input_type :: :string | :int | :float | :file | :bool | :select
  @type reason :: atom() | String.t()
  @type validator_function ::
          (term() -> {:ok, term()} | :ok | true | {:error, reason} | nil | false)
  @type input_options :: [
          validators: [validator_function],
          description: String.t(),
          options: Keyword.t()
        ]
  @type t :: {input_type, atom, input_options}

  defguard valid_type(type) when type in @valid_types

  for type <- @valid_types do
    if type == :select do
      @spec unquote(type)(atom(), Keyword.t(), input_options) :: t
      def select(name, select_options, opts \\ []) do
        {:select, name, select_options, opts}
      end
    else
      @spec unquote(type)(atom(), input_options) :: t
      def unquote(type)(name, opts \\ []) do
        {unquote(type), name, opts}
      end
    end
  end

  def types, do: @valid_types

  def validate_field(type, value) when valid_type(type) do
    do_validate(type, do_cast(value, type))
  end

  def validate_field(type, value, args) when valid_type(type) do
    do_validate(type, do_cast(value, type), args)
  end

  defp do_cast(value, :string), do: to_string(value)
  defp do_cast(value, :select), do: value

  defp do_cast(value, :int) when is_binary(value) do
    case Integer.parse(value) do
      {int, _} -> int
      _ -> value
    end
  end

  defp do_cast(value, :float) when is_binary(value) do
    case Float.parse(value) do
      {float, _} -> float
      _ -> value
    end
  end

  defp do_cast(value, :bool) when is_binary(value) do
    case String.downcase(value) do
      "true" -> true
      "false" -> false
      _ -> value
    end
  end

  defp do_cast(value, :int) when is_integer(value), do: value
  defp do_cast(value, :float) when is_float(value), do: value
  defp do_cast(value, :bool) when is_boolean(value), do: value
  defp do_cast(value, _), do: value

  defp do_validate(:string, value) when is_binary(value), do: {:ok, value}
  defp do_validate(:int, value) when is_integer(value), do: {:ok, value}
  defp do_validate(:float, value) when is_float(value), do: {:ok, value}
  defp do_validate(:bool, value) when is_boolean(value), do: {:ok, value}

  defp do_validate(:file, %module{} = value) when module == Plug.Upload, do: {:ok, value}

  defp do_validate(:file, path) when is_binary(path) do
    if File.exists?(path), do: {:ok, path}, else: {:error, :does_not_exist}
  end

  defp do_validate(_, _), do: {:error, :invalid}

  defp do_validate(:select, value, args) do
    if Enum.any?(args, fn {_key, select_value} -> value == select_value end) do
      {:ok, value}
    else
      {:error, :not_in_options}
    end
  end

  defp do_validate(_, _, _), do: {:error, :invalid}
end
