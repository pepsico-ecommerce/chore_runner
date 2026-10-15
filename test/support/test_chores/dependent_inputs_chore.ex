defmodule ChoreRunner.TestChores.DependentInputsChore do
  @moduledoc "Choose a region, then a city in it, then a district in that city."

  use ChoreRunner.Chore, persist_inputs_in_url?: true

  @cities %{
    "north" => [{"Oslo", "oslo"}, {"Bergen", "bergen"}],
    "south" => [{"Lisbon", "lisbon"}, {"Porto", "porto"}]
  }

  @districts %{
    "oslo" => [{"Frogner", "frogner"}, {"Grünerløkka", "grunerlokka"}],
    "bergen" => [{"Sentrum", "sentrum"}],
    "lisbon" => [{"Alfama", "alfama"}, {"Belém", "belem"}],
    "porto" => [{"Ribeira", "ribeira"}]
  }

  def inputs do
    [
      selectbox(:region, [{"North", "north"}, {"South", "south"}], prompt: "Choose a region"),
      selectbox(:city, &city_options/1, depends_on: [:region], prompt: "Choose a city"),
      selectbox(:district, &district_options/1, depends_on: [:city], prompt: "Choose a district"),
      selectbox(:mode, [{"Summary", "summary"}, {"Detailed", "detailed"}], default: "summary"),
      int(:guests,
        depends_on: [:mode],
        visible?: &(&1.mode == "detailed"),
        default: 2,
        validators: [&(&1 in 1..10 or {:error, "Choose between 1 and 10 guests"})]
      )
    ]
  end

  def run(inputs), do: {:ok, inputs}

  defp city_options(%{region: region}), do: Map.fetch!(@cities, region)
  defp district_options(%{city: city}), do: Map.fetch!(@districts, city)
end
