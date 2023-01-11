defmodule ChoreRunner.TestChore do
  use ChoreRunner.Chore

  def inputs do
    [
      string(:my_string),
      float(:my_float),
      file(:my_file),
      int(:sleep_length),
      bool(:sleep?)
    ]
  end

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
