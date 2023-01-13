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
    reporter = get_reporter()
    log("test")
    set_counter(:test, 5)
    inc_counter(:test, 1)

    spawn(fn ->
      log(reporter, "test from process")
      set_counter(reporter, :process_test, 10)
      inc_counter(reporter, :process_test, 2)
    end)

    {:ok, Map.put(attrs, :my_file_value, File.read!(my_file))}
  end
end
