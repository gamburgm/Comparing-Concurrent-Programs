input_file = '../example_test.json'

{:ok, json_text} = File.read(input_file)
test_input = Poison.decode!(json_text)

cand_registry = AbstractRegistry.create(CandStruct)

Enum.each(test_input["candidates"], fn %{"name" => n, "tax_rate" => tr, "threshold" => th} ->
  Candidate.spawn(n, tr, th, cand_registry)
end)

Enum.each(test_input["regions"], fn %{"name" => region_name, "voters" => voters} ->
  region_atom = String.to_atom(region_name)
  VoterRegistry.create(region_atom)
  Enum.each(voters, fn %{"name" => n, "voting_method" => %{"type" => "stupid_sort", "candidate" => c}} ->
    Voter.spawn(n, region_atom, cand_registry, StupidSort.generate(c), RegularVoting)
  end)
end)

region_manager = RegionManager.spawn(Enum.map(test_input["regions"], fn %{"name" => n} -> String.to_atom(n) end), cand_registry)

ref = Process.monitor(region_manager)

receive do
  {:DOWN, ^ref, _, _, _} -> :ok
end
