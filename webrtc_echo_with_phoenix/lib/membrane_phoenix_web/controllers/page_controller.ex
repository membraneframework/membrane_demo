defmodule MembranePhoenixWeb.PageController do
  use MembranePhoenixWeb, :controller

  alias Membrane.WebRTC.PhoenixSignaling

  def home(conn, _params) do
    # The home page is often custom made,
    # so skip the default app layout.

    unique_id = UUID.uuid4()

    Task.start(fn ->
      input_sg = PhoenixSignaling.new("#{unique_id}_egress")
      output_sg = PhoenixSignaling.new("#{unique_id}_ingress")
      Boombox.run(
        input: {:webrtc, input_sg},
        output: {:webrtc, output_sg}
      )
    end)

    conn = put_session(conn, :session_id, unique_id)

    html(conn, """
    <body class="bg-white" session-id=#{unique_id}>
    <video id="videoPlayer" controls muted autoplay></video>
    </body>
    <script src="assets/app.js"></script>
    """)
  end
end
