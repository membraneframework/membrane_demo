# Whisper

Livebook demo of [`Membrane.Whisper.TranscriberFilter`](https://github.com/membraneframework/membrane_whisper_plugin) — a Membrane filter that transcribes raw audio in real time using OpenAI's Whisper model via Bumblebee.

Open `whisper.livemd` in Livebook. It contains two pipelines: one that transcribes the system microphone live, and one that pulls an MP4 from a URL and transcribes its audio track. Transcripts stream into a Kino frame inside the notebook.
