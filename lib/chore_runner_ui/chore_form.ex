defmodule ChoreRunnerUI.ChoreForm do
  @moduledoc false

  alias ChoreRunner.Input

  def initial_values(inputs, persisted_values) do
    defaults =
      inputs
      |> Input.default_values()
      |> Map.new(fn {name, value} -> {to_string(name), value} end)

    inputs
    |> prompt_values()
    |> Map.merge(defaults)
    |> Map.merge(persistable_values(inputs, persisted_values))
  end

  def persistable_values(inputs, values) when is_map(values) do
    inputs
    |> Enum.reject(fn {type, _name, _opts} -> type == :file end)
    |> Enum.reduce(%{}, fn {_type, name, _opts}, acc ->
      case fetch_value(values, name) do
        {:ok, value} -> Map.put(acc, to_string(name), value)
        :error -> acc
      end
    end)
  end

  def persistable_values(_inputs, _values), do: %{}

  @doc """
  Puts every transitive dependent of a changed input back to its initial value, so a value
  chosen for a previous dependency value is never kept.
  """
  def reset_dependents(inputs, previous_values, values) do
    initial_values = initial_values(inputs, %{})

    {values, _changed} =
      Enum.reduce(inputs, {values, changed_names(inputs, previous_values, values)}, fn
        {_type, name, opts}, {values, changed} ->
          if Enum.any?(Input.dependencies(opts), &MapSet.member?(changed, &1)) do
            {reset_value(values, name, initial_values), MapSet.put(changed, name)}
          else
            {values, changed}
          end
      end)

    values
  end

  def form_data(chore_name, input_values) do
    %{"chore" => chore_name, "chore_attrs" => input_values}
  end

  defp prompt_values(inputs) do
    inputs
    |> Enum.filter(fn
      {:select, _name, opts} ->
        Keyword.has_key?(opts, :prompt) and not Keyword.has_key?(opts, :default)

      _input ->
        false
    end)
    |> Map.new(fn {_type, name, _opts} -> {to_string(name), ""} end)
  end

  defp changed_names(inputs, previous_values, values) do
    for {_type, name, _opts} <- inputs,
        fetch_value(previous_values, name) != fetch_value(values, name),
        into: MapSet.new(),
        do: name
  end

  defp reset_value(values, name, initial_values) do
    key = to_string(name)
    values = Map.delete(values, name)

    case Map.fetch(initial_values, key) do
      {:ok, value} -> Map.put(values, key, value)
      :error -> Map.delete(values, key)
    end
  end

  defp fetch_value(values, name) do
    case Map.fetch(values, name) do
      {:ok, value} -> {:ok, value}
      :error -> Map.fetch(values, to_string(name))
    end
  end
end
