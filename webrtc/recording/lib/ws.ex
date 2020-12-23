defmodule WS do
  use WebSockex

  def start_link(url, state) do
    extra_headers = [
      {"cookie", "credentials={\"username\":\"USERNAME\",\"password\":\"PASSWORD\"}"}
    ]

    WebSockex.start_link(url, __MODULE__, state, extra_headers: extra_headers)
  end

  @impl true
  def handle_frame({_type, msg}, state) do
    send(state.parent, {:event, Poison.decode!(msg)})
    {:ok, state}
  end

  def send_answer(pid, sdp, from, to) do
    %{
      "to" => [to],
      "event" => "answer",
      "from" => from,
      "data" => %{
        "type" => "answer",
        "sdp" => sdp
      }
    }
    |> do_send(pid)
  end

  def send_offer(pid, sdp, from, to) do
    %{
      "to" => to,
      "event" => "offer",
      "from" => from,
      "data" => %{
        "type" => "offer",
        "sdp" => sdp
      }
    }
    |> do_send(pid)
  end

  def send_candidate(pid, cand, sdpMLineIndex, sdpMid, to) do
    %{
      "to" => to,
      "event" => "candidate",
      "data" => %{
        "candidate" => cand,
        "sdpMLineIndex" => sdpMLineIndex,
        "sdpMid" => sdpMid
      }
    }
    |> do_send(pid)
  end

  def send_recorded(pid, file_name, from, to) do
    %{
      "from" => from,
      "to" => to,
      "event" => "recorded",
      "data" => %{
        "file_name" => file_name
      }
    }
    |> do_send(pid)
  end

  defp do_send(data, pid) do
    WebSockex.send_frame(pid, {:text, Poison.encode!(data)})
  end
end
