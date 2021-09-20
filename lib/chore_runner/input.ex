defmodule ChoreRunner.Input do
  @valid_types ~w(string int float file bool)a

  defguard valid_type(type) when type in @valid_types

  for type <- @valid_types do
    def unquote(type)(name, opts \\ []) do
      {unquote(type), name, opts}
    end
  end

  def types, do: @valid_types

  def validate_field(type, value) when valid_type(type) do
    do_validate(type, do_cast(value, type))
  end

  defp do_cast(value, :string), do: to_string(value)

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
end
