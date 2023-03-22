defmodule ChoreRunner.Downloads.TemporaryDiskStorageService do
  alias ChoreRunner.Downloads.StorageService
  @behaviour StorageService
  @file_dir_name "chore_runner_temporary_disk_storage_service_directory"

  @impl StorageService
  def save_file(name, opts \\ []) do
    with :ok <- ensure_dir(),
         id = ChoreRunner.gen_id(),
         file = %{
           id: id,
           name: name,
           type: MIME.from_path(name),
           path: build_write_filepath(id, name)
         },
         :ok <- write_file(file.path, opts[:path], opts[:body]) do
      {:ok, Map.put(file, :created_at, File.stat!(file.path).mtime)}
    end
  end

  @impl StorageService
  def list_files do
    case File.ls(dir()) do
      {:ok, files} ->
        {:ok, Enum.map(files, &build_file_from_saved_path/1)}

      {:error, :enoent} ->
        {:ok, []}

      error ->
        error
    end
  end

  @impl StorageService
  def delete_file(%{path: path} = _file), do: File.rm(path)

  @impl StorageService
  def file_url(%{id: id} = _file, download_plug_path: download_plug_path),
    do: Path.join(download_plug_path, id)

  # @impl StorageService
  # def extra_ui_info do
  #   Application.ensure_started(:sasl)
  #   Application.ensure_started(:os_mon)

  #   percentage_available =
  #     :disksup.get_disk_data()
  #     |> List.first()
  #     |> case do
  #       {_, _, percentage_available} ->
  #         "#{percentage_available}%"

  #       _ ->
  #         "Unknown"
  #     end

  #   %{
  #     "Available Disk Space" => percentage_available
  #   }
  # end

  defp write_file(write_path, path, nil) when not is_nil(path), do: File.cp(path, write_path)
  defp write_file(write_path, nil, body) when not is_nil(body), do: File.write(write_path, body)

  defp build_file_from_saved_path(path) do
    %{"id" => id, "name" => name} = Regex.named_captures(~r/^(?<id>[\da-z]+)_(?<name>.+)$/, path)
    path = Path.join(dir(), path)
    stat = File.stat!(path)

    %{
      id: id,
      name: name,
      type: MIME.from_path(path),
      path: path,
      created_at: stat.mtime |> NaiveDateTime.from_erl!(),
      size: stat.size,
      node: node()
    }
  end

  defp build_write_filepath(id, name), do: Path.join(dir(), "#{id}_#{name}")

  defp dir, do: Path.join(System.tmp_dir!(), @file_dir_name)

  defp ensure_dir do
    case File.mkdir(dir()) do
      :ok -> :ok
      {:error, :eexist} -> :ok
      error -> error
    end
  end
end
