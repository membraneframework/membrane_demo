defmodule WebRTCToHLS.Utils do
  @moduledoc false

  @spec pid_to_path_prefix(pid()) :: String.t()
  def pid_to_path_prefix(pid) do
    pid |> pid_to_hash()
  end

  @spec hls_path(prefix :: String.t()) :: String.t()
  def hls_path(prefix) do
    [hls_mount_path(), prefix] |> Path.join()
  end

  @spec hls_path(prefix :: String.t(), filename :: String.t()) :: String.t()
  def hls_path(prefix, filename) do
    [hls_mount_path(), prefix, filename] |> Path.join()
  end

  defp hls_mount_path(), do: Application.fetch_env!(:membrane_webrtc_to_hls_demo, :hls_mount_path)

  defp pid_to_hash(pid) do
    :crypto.hash(:md5, :erlang.pid_to_list(pid)) |> Base.encode16(case: :lower)
  end
end
