defmodule ChoreRunner.DownloadsTest do
  use ExUnit.Case, async: false

  alias ChoreRunner.Downloads
  alias ChoreRunner.Downloads.TemporaryDiskStorageService

  @dir Path.join(System.tmp_dir!(), "chore_runner_temporary_disk_storage_service_directory")

  setup do
    File.rm_rf!(@dir)
    on_exit(fn -> File.rm_rf!(@dir) end)
    :ok
  end

  describe "list_downloads/1" do
    test "returns empty list when no files exist" do
      assert Downloads.list_downloads() == []
    end

    test "sorts by created_at desc and limits to 50 by default" do
      created_files =
        for i <- 1..60 do
          {:ok, file} =
            TemporaryDiskStorageService.save_file("file_#{i}.txt", body: "content #{i}")

          mtime =
            {{2026, 1, 1}, {0, 0, 0}}
            |> NaiveDateTime.from_erl!()
            |> NaiveDateTime.add(i, :second)
            |> NaiveDateTime.to_erl()

          File.touch!(file.path, mtime)
          %{file | created_at: NaiveDateTime.from_erl!(mtime)}
        end

      results = Downloads.list_downloads()

      assert length(results) == 50

      timestamps = Enum.map(results, & &1.created_at)
      assert timestamps == Enum.sort(timestamps, {:desc, NaiveDateTime})

      newest_50_names =
        created_files
        |> Enum.sort_by(& &1.created_at, {:desc, NaiveDateTime})
        |> Enum.take(50)
        |> Enum.map(& &1.name)
        |> Enum.sort()

      assert Enum.map(results, & &1.name) |> Enum.sort() == newest_50_names
    end

    test "honors custom limit" do
      for i <- 1..5 do
        {:ok, _} = TemporaryDiskStorageService.save_file("file_#{i}.txt", body: "x")
      end

      assert length(Downloads.list_downloads(3)) == 3
    end
  end
end
