defmodule Chore.TestChore do
  use Chore

  input :my_string, :string
  input :my_float, :float
  input :my_file, :file
  input :sleep_length, :int
  input :sleep?, :bool

  def run(
        %{
          my_string: _my_string,
          my_float: _my_float,
          my_file: my_file,
          sleep_length: sleep_length,
          sleep?: sleep?
        } = attrs
      ) do
    if sleep?, do: Process.sleep(sleep_length)
    {:ok, Map.put(attrs, :my_file_value, File.read!(my_file))}
  end
end
