defmodule ChoreRunner.TestChores.PersistedCrossFieldValidationChore do
  use ChoreRunner.Chore, persist_inputs_in_url?: true

  def inputs do
    [
      selectbox(:buyer_type, [{"Guest", "guest"}, {"Registered", "registered"}],
        default: "registered"
      ),
      int(:number_of_orders, default: 4),
      string(:generation_key),
      int(:batch_size, default: 500)
    ]
  end

  def validate_inputs(%{buyer_type: "registered", number_of_orders: number_of_orders})
      when rem(number_of_orders, 2) != 0,
      do: {:error, number_of_orders: ["Registered runs require an even number of Orders."]}

  def validate_inputs(inputs), do: {:ok, inputs}

  def run(inputs), do: {:ok, inputs}
end
