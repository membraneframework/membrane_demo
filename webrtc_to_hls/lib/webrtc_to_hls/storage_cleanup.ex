defmodule WebRTCToHLS.StorageCleanup do
  alias WebRTCToHLS.Helpers

  @spec remove_directory(directory_name :: String.t()) :: [binary()]
  def remove_directory(directory_name),
    do: directory_name |> Helpers.hls_output_path() |> File.rm_rf!()

  @spec clean_unused_directories() :: :ok
  def clean_unused_directories() do
    all_paths = list_storage_directories() |> MapSet.new()

    all_paths
    |> Enum.map(&Helpers.hls_output_path(&1))
    |> Enum.each(&File.rm_rf!(&1))
  end

  defp list_storage_directories() do
    case Helpers.hls_output_mount_path() |> File.ls() do
      {:ok, dirs} -> dirs
      {:error, :enoent} -> []
    end
  end
end
