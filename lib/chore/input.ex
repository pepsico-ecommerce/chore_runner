defmodule Chore.Input do
  @valid_types ~w(string int float file bool)a

  defguard valid_type(type) when type in @valid_types

  def types, do: @valid_types

  def validate(type, value) when valid_type(type) do
    do_validate(type, value)
  end

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
