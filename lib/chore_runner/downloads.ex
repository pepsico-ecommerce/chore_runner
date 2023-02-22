defmodule ChoreRunner.Downloads do
  alias ChoreRunner.Downloads.StorageService

  def create_download(filename, opts), do: StorageService.save_file(filename, opts)

  def list_downloads do
    with {:ok, local_downloads} <- StorageService.list_files(),
         {results, _} <-
           :rpc.multicall(Node.list(), ChoreRunner.Downloads.StorageService, :list_files, []) do
      results
      |> Enum.flat_map(fn
        {:ok, files} -> files
        _ -> []
      end)
      |> Kernel.++(local_downloads)
    end
  end

  def delete_download(file) do
    with {:error, _} <- StorageService.delete_file(file),
         {results, _} <-
           :rpc.multicall(Node.list(), ChoreRunner.Downloads.StorageService, :delete_file, [file]) do
      Enum.find(results, {:error, :enoent}, &(&1 == :ok))
    end
  end
end
