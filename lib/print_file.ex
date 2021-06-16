defmodule Chore.PrintFile do
  use Chore

  input :my_file, :file

  def run(%{my_file: %{path: path}}) do
    IO.inspect(File.read!(path))
    {:ok, :done}
  end
end
