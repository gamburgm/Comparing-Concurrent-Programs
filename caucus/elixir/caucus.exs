cand_registry = AbstractRegistry.create(CandStruct)

Candidate.spawn("Bernie", 50, 0, cand_registry)
Candidate.spawn("Biden", 25, 0, cand_registry)
Candidate.spawn("Tulsi", 10, 0, cand_registry)
StubbornCandidate.spawn("1", 10, cand_registry)
Candidate.spawn("2", 10, 0, cand_registry)
Candidate.spawn("3", 10, 0, cand_registry)
Candidate.spawn("4", 10, 0, cand_registry)
Candidate.spawn("5", 10, 0, cand_registry)
Candidate.spawn("6", 10, 0, cand_registry)


VoterRegistry.create(:a)

Voter.spawn("ABC", :a, cand_registry, StupidSort.generate("Tulsi"), RegularVoting)
Voter.spawn("DEF", :a, cand_registry, StupidSort.generate("Tulsi"), RegularVoting)
Voter.spawn("GHI", :a, cand_registry, StupidSort.generate("Tulsi"), RegularVoting)
Voter.spawn("JKL", :a, cand_registry, StupidSort.generate("Biden"), RegularVoting)
Voter.spawn("MNO", :a, cand_registry, StupidSort.generate("Biden"), RegularVoting)
Voter.spawn("PQR", :a, cand_registry, StupidSort.generate("Biden"), RegularVoting)
Voter.spawn("STU", :a, cand_registry, StupidSort.generate("Biden"), RegularVoting)
Voter.spawn("VWX", :a, cand_registry, StupidSort.generate("Biden"), RegularVoting)
Voter.spawn("YZ1", :a, cand_registry, StupidSort.generate("Biden"), RegularVoting)
Voter.spawn("g", :a, cand_registry, StupidSort.generate("Biden"), SleepThroughVoting)
SuicidalSubscriber.mock_spawn(cand_registry)

VoterRegistry.create(:b)

Voter.spawn("1", :b, cand_registry, StupidSort.generate("Bernie"), RegularVoting)
Voter.spawn("2", :b, cand_registry, StupidSort.generate("Bernie"), RegularVoting)
Voter.spawn("3", :b, cand_registry, StupidSort.generate("Bernie"), RegularVoting)
Voter.spawn("4", :b, cand_registry, StupidSort.generate("Biden"), RegularVoting)
Voter.spawn("5", :b, cand_registry, StupidSort.generate("Biden"), RegularVoting)
Voter.spawn("6", :b, cand_registry, StupidSort.generate("Biden"), RegularVoting)
Voter.spawn("7", :b, cand_registry, StupidSort.generate("Biden"), RegularVoting)
Voter.spawn("8", :b, cand_registry, StupidSort.generate("Biden"), RegularVoting)
Voter.spawn("9", :b, cand_registry, StupidSort.generate("Biden"), RegularVoting)

VoterRegistry.create(:c)

Voter.spawn("10", :c, cand_registry, StupidSort.generate("Bernie"), RegularVoting)
Voter.spawn("11", :c, cand_registry, StupidSort.generate("Bernie"), RegularVoting)
Voter.spawn("12", :c, cand_registry, StupidSort.generate("Bernie"), RegularVoting)
Voter.spawn("13", :c, cand_registry, StupidSort.generate("Bernie"), RegularVoting)
Voter.spawn("14", :c, cand_registry, StupidSort.generate("Bernie"), RegularVoting)

VoterRegistry.create(:d)

Voter.spawn("14", :d, cand_registry, StupidSort.generate("Tulsi"), RegularVoting)
Voter.spawn("15", :d, cand_registry, StupidSort.generate("Tulsi"), RegularVoting)
Voter.spawn("16", :d, cand_registry, StupidSort.generate("Tulsi"), RegularVoting)
Voter.spawn("17", :d, cand_registry, StupidSort.generate("Tulsi"), RegularVoting)
Voter.spawn("18", :d, cand_registry, StupidSort.generate("Tulsi"), RegularVoting)

VoterRegistry.create(:e)

Voter.spawn("19", :e, cand_registry, StupidSort.generate("6"), RegularVoting)
Voter.spawn("20", :e, cand_registry, StupidSort.generate("6"), RegularVoting)
Voter.spawn("21", :e, cand_registry, StupidSort.generate("6"), RegularVoting)
Voter.spawn("22", :e, cand_registry, StupidSort.generate("6"), RegularVoting)
Voter.spawn("23", :e, cand_registry, StupidSort.generate("6"), RegularVoting)

region_manager = RegionManager.spawn([:a, :b, :c, :d, :e], cand_registry)

ref = Process.monitor(region_manager)

receive do
  {:DOWN, ^ref, _, _, _} -> :ok
end

