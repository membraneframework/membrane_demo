# Talk with Gemini

Script demo of [`Membrane.Gemini.Bin`](https://github.com/membraneframework/membrane_gemini_plugin) — a Membrane element that wraps Google's Gemini Live API for low-latency bidirectional voice conversation, with transcription events on both sides.

The pipeline captures audio from the default input device via PortAudio, streams it to Gemini, and plays the model's spoken reply back through the default output device; user and model transcripts are logged. You can also type lines in the terminal to prompt the model in text.

Run with:

```
GEMINI_API_KEY="your API key" elixir talk_with_gemini.exs
```

Use headphones — otherwise the microphone picks up the model's own voice and it ends up talking to itself.
