# Benchmarks

Currently, there are two benchmarks:
* simple - one big room 
* multiroom - multiple rooms with a small number of peers

To run stampede benchmarks, type from the root directory (videoroom_advanced) 

```elixir
MIX_ENV=benchmark mix run benchmarks/<benchmark_name>.exs
```

To run testRTC benchmarks on `m2` machine, type from the root directory (videoroom_advanced)

```elixir
MIX_ENV=benchmark VIRTUAL_HOST=webrtc.membrane.work mix run benchmarks/testrtc.exs <api_key> <test_name>
```

where `test_name` is either `beamchmark-simple` or `beamchmark-multiroom`.

## Results

Results are located under [results](results).
Below, there are testbed and test scenarios descriptions.

### Testbed
`m2` testing machine with AMD EPYC 7502P 32-Core Processor and 128 GB RAM

### Test scenarios
* simple - one room with 20 participants (testRTC birds video) plus video from my camera as I was controlling if everyone connected succesfully
* multiroom - nine rooms, each with 5 participants (testRTC birds video)

