# defmodule ApiV1.Chores.Example do
#   use ChoreRunner.Chore
#   alias ChoreRunner.Reporter

#   def inputs do
#     [string(:str, [])]
#   end

#   def restriction, do: :none

#   def run(%{str: _str}) do
#     Reporter.log("Starting")
#     Process.sleep(100_000)

#     Enum.each(1..100, fn n ->
#       Process.sleep(10)
#       set_counter(:percent_done, n)
#     end)

#     Reporter.log("Wrapping up")

#     {:ok, :done}
#   end
# end
