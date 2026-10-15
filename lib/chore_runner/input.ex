defmodule ChoreRunner.Input do
  @valid_types ~w(string int float file bool select)a

  @type input_type :: :string | :int | :float | :file | :bool | :select
  @type reason :: atom() | String.t()
  @type validator_function ::
          (term() -> {:ok, term()} | :ok | true | {:error, reason} | nil | false)
  @type select_options :: list() | map()
  @type dependency_values :: %{atom() => term()}
  @type select_options_provider ::
          select_options() | (-> select_options()) | (dependency_values() -> select_options())
  @type input_options :: [
          validators: [validator_function],
          description: String.t(),
          default: term(),
          options: select_options_provider(),
          prompt: String.t(),
          depends_on: [atom()],
          visible?: (dependency_values() -> boolean())
        ]
  @type t :: {input_type, atom, input_options}

  defguard valid_type(type) when type in @valid_types

  for type <- @valid_types -- [:select] do
    @spec unquote(type)(atom(), input_options) :: t
    def unquote(type)(name, opts \\ []) do
      {unquote(type), name, opts}
    end
  end

  @spec selectbox(atom(), select_options_provider(), input_options()) :: t()
  def selectbox(name, options_or_provider, opts \\ []) do
    {:select, name, Keyword.put(opts, :options, options_or_provider)}
  end

  def types, do: @valid_types

  def validate_field(type, value, opts \\ []) when valid_type(type) do
    do_validate(type, do_cast(value, type), opts)
  end

  @spec select_options(input_options()) :: select_options()
  def select_options(opts) do
    opts
    |> Keyword.fetch!(:options)
    |> resolve_select_options()
  end

  @doc """
  Resolves select options for an input whose provider receives the validated values of
  the inputs listed in `:depends_on`.
  """
  @spec select_options(input_options(), dependency_values()) :: select_options()
  def select_options(opts, dependency_values) do
    opts
    |> Keyword.fetch!(:options)
    |> resolve_select_options(dependency_values)
  end

  @spec dependencies(input_options()) :: [atom()]
  def dependencies(opts), do: Keyword.get(opts, :depends_on, [])

  @doc """
  Returns whether an input with satisfied dependencies should be shown and validated.
  """
  @spec visible?(input_options(), dependency_values()) :: boolean()
  def visible?(opts, dependency_values) do
    case Keyword.fetch(opts, :visible?) do
      {:ok, visible?} -> visible?.(dependency_values) == true
      :error -> true
    end
  end

  @doc """
  Raises when an input declares dependencies the form cannot resolve.

  Dependencies must name non-file inputs declared earlier in the list, which also rules out
  cycles. Dependency-aware select providers and `:visible?` require `:depends_on`.
  """
  @spec validate_dependencies!([t()]) :: :ok
  def validate_dependencies!(inputs) do
    Enum.reduce(inputs, %{}, fn {type, name, opts}, declared_types ->
      validate_input_dependencies!(name, opts, declared_types)
      Map.put(declared_types, name, type)
    end)

    :ok
  end

  @spec default_values([t()]) :: map()
  def default_values(inputs) do
    inputs
    |> Enum.filter(fn {_type, _name, opts} -> Keyword.has_key?(opts, :default) end)
    |> Map.new(fn {_type, name, opts} -> {name, Keyword.fetch!(opts, :default)} end)
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

  defp do_validate(:string, value, _opts) when is_binary(value), do: {:ok, value}
  defp do_validate(:int, value, _opts) when is_integer(value), do: {:ok, value}
  defp do_validate(:float, value, _opts) when is_float(value), do: {:ok, value}
  defp do_validate(:bool, value, _opts) when is_boolean(value), do: {:ok, value}

  defp do_validate(:file, %module{} = value, _opts) when module == Plug.Upload,
    do: {:ok, value}

  defp do_validate(:file, path, _opts) when is_binary(path) do
    if File.exists?(path), do: {:ok, path}, else: {:error, :does_not_exist}
  end

  defp do_validate(:select, value, opts) do
    options_by_form_value =
      opts
      |> select_options()
      |> option_values()
      |> options_by_form_value()

    case Map.fetch(options_by_form_value, form_value(value)) do
      {:ok, declared_value} -> {:ok, declared_value}
      :error -> {:error, :not_in_options}
    end
  end

  defp do_validate(_, _, _opts), do: {:error, :invalid}

  defp resolve_select_options(provider) when is_function(provider, 0) do
    provider.()
    |> validate_select_options!()
  end

  defp resolve_select_options(provider) when is_function(provider, 1) do
    raise ArgumentError,
          "select options provider expects dependency values; declare :depends_on and use select_options/2"
  end

  defp resolve_select_options(options), do: validate_select_options!(options)

  defp resolve_select_options(provider, dependency_values) when is_function(provider, 1) do
    dependency_values
    |> provider.()
    |> validate_select_options!()
  end

  defp resolve_select_options(provider, _dependency_values), do: resolve_select_options(provider)

  defp validate_input_dependencies!(name, opts, declared_types) do
    dependencies = dependencies(opts)

    unless is_list(dependencies) and Enum.all?(dependencies, &is_atom/1) do
      raise ArgumentError,
            "#{inspect(name)} :depends_on must be a list of input names; got: #{inspect(dependencies)}"
    end

    Enum.each(dependencies, fn dependency ->
      case Map.fetch(declared_types, dependency) do
        {:ok, :file} ->
          raise ArgumentError,
                "#{inspect(name)} cannot depend on file input #{inspect(dependency)}"

        {:ok, _type} ->
          :ok

        :error ->
          raise ArgumentError,
                "#{inspect(name)} depends on #{inspect(dependency)}, which must be an input declared before it"
      end
    end)

    if dependencies == [] and is_function(Keyword.get(opts, :options), 1) do
      raise ArgumentError,
            "#{inspect(name)} has a select options provider that expects dependency values but declares no :depends_on"
    end

    case Keyword.fetch(opts, :visible?) do
      :error ->
        :ok

      {:ok, _visible?} when dependencies == [] ->
        raise ArgumentError, "#{inspect(name)} declares :visible? without :depends_on"

      {:ok, visible?} when is_function(visible?, 1) ->
        :ok

      {:ok, visible?} ->
        raise ArgumentError,
              "#{inspect(name)} :visible? must be a one-arity function; got: #{inspect(visible?)}"
    end
  end

  defp validate_select_options!(options) when is_list(options) or is_map(options), do: options

  defp validate_select_options!(options) do
    raise ArgumentError,
          "select options must be a list, map, or zero-arity function returning one; got: #{inspect(options)}"
  end

  defp option_values(options) when is_map(options) do
    options
    |> Enum.flat_map(&option_entry_values/1)
  end

  defp option_values(options) when is_list(options) do
    Enum.flat_map(options, &option_entry_values/1)
  end

  defp option_entry_values(:hr), do: []
  defp option_entry_values({:hr, nil}), do: []

  defp option_entry_values({_label, grouped_options})
       when is_list(grouped_options) or is_map(grouped_options),
       do: option_values(grouped_options)

  defp option_entry_values({_label, value}), do: [value]

  defp option_entry_values(option) when is_list(option) do
    if Keyword.has_key?(option, :key) and Keyword.has_key?(option, :value) do
      [Keyword.fetch!(option, :value)]
    else
      raise ArgumentError,
            "select option keyword lists must contain :key and :value; got: #{inspect(option)}"
    end
  end

  defp option_entry_values(value), do: [value]

  defp options_by_form_value(values) do
    Enum.reduce(values, %{}, fn value, acc ->
      serialized_value = form_value(value)

      case Map.fetch(acc, serialized_value) do
        {:ok, existing_value} when existing_value !== value ->
          raise ArgumentError,
                "select option values must have unique HTML representations; " <>
                  "#{inspect(existing_value)} and #{inspect(value)} both serialize as #{inspect(serialized_value)}"

        _ ->
          Map.put_new(acc, serialized_value, value)
      end
    end)
  end

  defp form_value(value) when is_binary(value), do: value
  defp form_value(value) when is_atom(value) or is_number(value), do: to_string(value)

  defp form_value(value) do
    raise ArgumentError,
          "select option values must be strings, atoms, or numbers; got: #{inspect(value)}"
  end
end
