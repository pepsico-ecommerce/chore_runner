defmodule ChoreRunner.Example do
  use ChoreRunner.Chore
  alias ChoreRunner.Reporter

  input :str, :string do
    validate(&validate_str1/1)
    validate(&validate_str2/1)
    validate(&validate_str3/1)

    validate(fn _str ->
      :ok
    end)
  end

  def restriction, do: :none

  def run(%{str: _str}) do
    Reporter.log("Starting")

    Enum.each(1..100, fn n ->
      Process.sleep(10)
      Reporter.report_percent(n)
    end)

    Reporter.log("Wrapping up")

    {:ok, :done}
  end

  defp validate_str1(_str), do: :ok
  defp validate_str2(_str), do: :ok
  defp validate_str3(_str), do: :ok
end
