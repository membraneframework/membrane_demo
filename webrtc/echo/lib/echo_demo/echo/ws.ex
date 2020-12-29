defmodule WS do
  use WebSockex

  def start_link(url, state) do
    extra_headers = [
      {"cookie", "credentials={\"username\":\"USERNAME\",\"password\":\"PASSWORD\"}"}
    ]

    WebSockex.start_link(url, __MODULE__, state, extra_headers: extra_headers)
  end

  def handle_frame({_type, msg}, state) do
    send(state[:parent], {:event, msg})
    {:ok, state}
  end

  def send_answer(pid, sdp, from, to) do
    msg =
      Poison.encode!(%{
        "to" => [to],
        "event" => "answer",
        "from" => from,
        "data" => %{
          "type" => "answer",
          "sdp" => sdp
        }
      })

    frame = {:text, msg}
    WebSockex.send_frame(pid, frame)
  end

  def send_offer(pid, sdp, from, to) do
    msg =
      Poison.encode!(%{
        "to" => to,
        "event" => "offer",
        "from" => from,
        "data" => %{
          "type" => "offer",
          "sdp" => sdp
        }
      })

    frame = {:text, msg}
    WebSockex.send_frame(pid, frame)
  end

  def send_candidate(pid, cand, sdpMLineIndex, sdpMid, to) do
    msg =
      Poison.encode!(%{
        "to" => to,
        "event" => "candidate",
        "data" => %{
          "candidate" => cand,
          "sdpMLineIndex" => sdpMLineIndex,
          "sdpMid" => sdpMid
        }
      })

    frame = {:text, msg}
    WebSockex.send_frame(pid, frame)
  end
end
