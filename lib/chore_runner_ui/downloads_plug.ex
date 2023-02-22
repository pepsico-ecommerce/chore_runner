defmodule ChoreRunnerUI.DownloadsPlug do
  import Plug.Conn
  alias ChoreRunner.Downloads.StorageService
  @buffer_size 1024

  def init(_), do: %{}

  def call(%{path_info: [id]} = conn, _) do
    current_node = node()

    case StorageService.find_file(id) do
      nil ->
        send_resp(conn, 404, "Not Found")

      %{path: path, node: ^current_node, name: name} ->
        # file exists on current node

        # Put correct disposition for named downloads
        conn
        |> put_resp_header("content-disposition", "attachment; filename=\"#{name}\"")
        |> send_file(200, path)

      %{node: _other_node, name: name} = file ->
        conn
        |> put_resp_header("content-disposition", "attachment; filename=\"#{name}\"")
        |> remote_send_chunked_file(file)
    end
  end

  defp remote_send_chunked_file(conn, file) do
    pid = self()
    ref = make_ref()
    # Open file on remote node
    :rpc.cast(file.node, __MODULE__, :safely_open_remote_file, [file.path, pid, ref])

    # Receive file device pid, and rpc pid linked to device pid
    {remote_pid_linked_to_opened_file, opened_file} =
      receive do
        {:open, remote_pid_linked_to_opened_file, opened_file, ^ref} ->
          {remote_pid_linked_to_opened_file, opened_file}
      end

    # Build binary stream that reads file from remote node, sending a heartbeat to rpc pid while reading

    file_stream =
      opened_file
      |> IO.binstream(@buffer_size)
      |> Stream.each(fn _ ->
        send(remote_pid_linked_to_opened_file, {:heartbeat, ref})
      end)

    # Set up http headers. setting the "content-length" header will cause cowboy to treat this as a streamed response instead of a chunked response
    chunked_conn =
      conn
      |> put_resp_header("Content-Transfer-Encoding", "binary")
      |> put_resp_header("content-length", to_string(file.size))
      |> put_resp_content_type(file.type)
      |> send_chunked(200)

    # Send chunked file from remote node
    conn =
      Enum.reduce(file_stream, chunked_conn, fn file_chunk, conn ->
        case chunk(conn, file_chunk) do
          {:ok, conn} ->
            conn

          {:error, _reason} ->
            conn
        end
      end)

    # Inform rpc pid it can safely end, this closes the file as well
    send(remote_pid_linked_to_opened_file, {:done, ref})
    conn
  end

  @doc false
  def safely_open_remote_file(path, remote_casting_pid, ref) do
    opened_file = File.open!(path)
    send(remote_casting_pid, {:open, self(), opened_file, ref})
    wait_for_send_completion(ref)
    File.close(opened_file)
  end

  defp wait_for_send_completion(ref) do
    receive do
      {:heartbeat, ^ref} ->
        wait_for_send_completion(ref)

      {:done, ^ref} ->
        :done
    after
      10000 ->
        :timeout
    end
  end
end
