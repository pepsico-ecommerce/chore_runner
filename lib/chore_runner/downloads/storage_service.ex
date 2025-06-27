defmodule ChoreRunner.Downloads.StorageService do
  @typedoc """
  Must have the appropriate file extension to be considered a valid name.
  """
  @type name :: String.t()
  @type file_path :: String.t()
  @type body :: binary()
  @typedoc """
  While both :path and :body are optional, at least one is required. The application will raise if both are provided.
  """
  @type opts :: [path: file_path(), body: body()]
  @type reason :: any()
  @type file :: %{
          required(:id) => String.t(),
          required(:name) => String.t(),
          required(:type) => String.t(),
          required(:created_at) => DateTime.t(),
          optional(:chore_id) => String.t(),
          optional(atom()) => any()
        }
  @callback save_file(name, opts) :: {:ok, file()} | {:error, reason()}
  @callback list_files() :: {:ok, [file()]} | {:error, reason()}
  @callback delete_file(file()) :: :ok | {:error, reason()}
  @callback file_url(file(), list()) :: String.t()
  # @callback extra_ui_info() :: map()

  @storage_service Application.compile_env(
                     :chore_runner,
                     :storage_service,
                     ChoreRunner.Downloads.TemporaryDiskStorageService
                   )

  def save_file(name, opts) do
    cond do
      opts[:path] && opts[:body] ->
        raise "Only one of the options :path or :body can be provided to the function ChoreRunner.Downloads.StorageService.save_file/2 at a time."

      is_nil(opts[:path]) and is_nil(opts[:body]) ->
        raise "One of the options :path or :body must be provided to the function ChoreRunner.Downloads.StorageService.save_file/2."

      true ->
        @storage_service.save_file(name, opts)
    end
  end

  defdelegate list_files(), to: @storage_service
  defdelegate delete_file(file), to: @storage_service
  defdelegate file_url(file, opts), to: @storage_service
  # defdelegate extra_ui_info(), to: @storage_service

  def find_file(id), do: find_files_by(:id, id) |> List.first()

  def find_files_by_chore_id(chore_id), do: find_files_by(:chore_id, chore_id)

  defp find_files_by(key, val) do
    ChoreRunner.Downloads.list_downloads()
    |> Enum.filter(&(&1[key] == val))
  end
end
