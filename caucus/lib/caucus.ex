# An actor aiming to receive the support of voters and win Regions
defmodule Candidate do
  # Initialize and setup a Candidate for election
  # Name TaxRate Threshold PID -> PID
  def spawn(name, tax_rate, threshold, cand_registry) do
    spawn fn ->
      send cand_registry, {:publish, self(), %CandStruct{name: name, tax_rate: tax_rate, pid: self()}}
      loop(name, tax_rate, threshold, cand_registry)
    end
  end

  # Hold conversations with other actors
  # Name TaxRate Threshold PID -> void
  defp loop(name, tax_rate, threshold, cand_registry) do
    receive do
      {:tally, tally} -> 
        if tally[name] < threshold do
          send cand_registry, {:remove, %CandStruct{name: name, tax_rate: tax_rate, pid: self()}}
        else
          loop(name, tax_rate, threshold, cand_registry)
        end
      :loser -> :noop
    end
  end
end

defmodule StubbornCandidate do
  # Initialize and setup a Candidate for election
  # Name TaxRate Threshold PID -> PID
  def spawn(name, tax_rate, cand_registry) do
    spawn fn ->
      send cand_registry, %CandStruct{name: name, tax_rate: tax_rate, pid: self()}
      loop(name, tax_rate, cand_registry)
    end
  end

  # Hold conversations with other actors
  # Name TaxRate Threshold PID -> void
  defp loop(name, tax_rate, cand_registry) do
    receive do
      :loser ->
        send cand_registry, {:remove, self()}
        send cand_registry, {:publish, self(), %CandStruct{name: name, tax_rate: tax_rate, pid: self()}}
      true ->
        loop(name, tax_rate, cand_registry)
    end
  end
end

defmodule VoterRegistry do
  defstruct [:voters]

  # Initialize a Voter Registry for managing the voters eligible to vote in each region
  # -> PID
  def create do
    spawn fn -> 
      receive do
        {:registration_info, deadline_time, regions} ->
          start_registration(deadline_time, regions) 
      end
    end
  end

  # Initialize a registration deadline for the Voter Registry
  # Time [Region] -> void
  defp start_registration(deadline_time, regions) do
    Process.send_after self(), :deadline, deadline_time - :os.system_time(:millisecond)
    manage_registrants(%{}, deadline_time, MapSet.new(regions))
  end

  # Accept registration requests from voters
  # {Name -> {Region, PID}} Time Set(Region)
  defp manage_registrants(reg_info, deadline_time, valid_regions) do
    update_registration = fn name, region, should_be_registered? ->
      if registered?(reg_info, name) && valid_region?(valid_regions, region) do
        manage_registrants(Map.put(reg_info, name, region), deadline_time, valid_regions)
      else
        manage_registrants(reg_info, deadline_time, valid_regions)
      end
    end

    create_registration_record = fn name, region -> update_registration(name, region, true) end
    change_registration_record = fn name, region -> update_registration(name, region, false) end

    receive do
      :deadline ->
        voters_per_region = Enum.reduce(reg_info, %{}, fn {voter, region}, acc -> 
          Map.update(acc, region, MapSet.new([voter]), fn voters -> MapSet.put(voters, voter) end)
        end)
        serve_reg_info(voters_per_region)

      {:register, name, region} -> create_registration_record(name, region)
      {:change_reg, name, region} -> update_registration_record(name, region)
      {:unregister, name} ->
        if registered?(reg_info, name) do
          manage_registrants(Map.delete(reg_info, name), deadline_time, valid_regions)
        else
          manage_registrants(reg_info, deadline_time, valid_regions)
        end
    end
  end

  # Respond to requests for the voters registered in a region
  # {Region -> Set({Name, PID})}
  defp serve_reg_info(voters_per_region) do
    receive do
      {:voter_roll, pid, region} ->
        send pid, %VoterRegistry{voters: Map.get(voters_per_region, region, MapSet.new())}
    end
    serve_reg_info(voters_per_region)
  end

  defp valid_region?(regions, region) do
    MapSet.member?(regions, region)
  end

  defp registered?(reg_info, name) do
    Map.has_key?(reg_info, name)
  end
end

# A pub/sub server for data of some struct
defmodule AbstractRegistry do
  defstruct [:values, :type]

  # initialize a new AbstractRegistry
  def create(type) do
    IO.puts "We exist with type #{inspect type}!"
    spawn fn -> loop(type, MapSet.new(), Map.new(), MapSet.new()) end
  end

  defp loop(type, values, publications, subscribers) do
    receive do
      # Receiving a struct of the module Type, update all current subscribers with new data
      {:publish, pid, %^type{} = new_val} ->
        IO.puts "New value: #{inspect new_val} for #{inspect type} from #{inspect pid}!"
        new_values = MapSet.put(values, new_val)
        Enum.each(subscribers, fn s -> send s, the_package(values, type) end)
        loop(type, new_values, Map.put(publications, pid, new_val), subscribers)
      # Add a new subscriber to the list and update them with the latest
      {:subscribe, pid} -> 
        IO.puts "We have a new subscriber! #{inspect pid} for #{inspect type}!"
        Process.monitor pid
        send pid, the_package(values, type)
        loop(type, values, publications, MapSet.put(subscribers, pid))
      # Send a single-instance message to a process of the most recent snapshot of data
      {:msg, pid} ->
        IO.puts "Process #{inspect pid} is requesting a message!"
        send pid, the_package(values, type)
        loop(type, values, publications, subscribers)
      # Remove a piece of data from the published data
      {:remove, pid} ->
        IO.puts "Actor #{inspect pid} is removing itself from the Registry!"
        loop(type, MapSet.delete(values, publications[pid]), Map.delete(publications, pid), subscribers)
      {:DOWN, _, _, dead_pid, _} ->
        IO.puts "Actor #{inspect dead_pid} has died!"
        loop(type, MapSet.delete(values, publications[dead_pid]), Map.delete(publications, dead_pid), MapSet.delete(subscribers, dead_pid))
    end
  end

  # produce the payload delivered to subscribers of the server
  defp the_package(values, type) do
    %AbstractRegistry{values: values, type: type}
  end
end

# Create and associate a Registry for VoterStructs with a Region
defmodule VoterParticipationRegistry do
  def create(region) do
    Process.register(AbstractRegistry.create(VoterStruct), region)
  end
end

# The VoterStruct: see top
defmodule VoterStruct do
  defstruct [:name, :pid]
end

# Shared behavior between voters
defmodule Voter do
  # Initialize a new voter
  # Name Region PID PID ([Setof Candidate] -> [Setof Candidate]) VotingStrategy -> PID
  def spawn(name, region, cand_registry, voter_registry, event_registry, prioritize_cands, voting_strategy) do
    spawn fn ->
      participation_registry = Process.whereis region
      send participation_registry, {:publish, self(), %VoterStruct{name: name, pid: self()}}
      send voter_registry, {:register, name, region}
      send cand_registry, {:subscribe, self()}
      loop(name, region, MapSet.new(), prioritize_cands, voting_strategy, event_registry)
    end
  end

  # Respond to messages sent to a voter
  # Name [Setof Candidate] ([Enumerable Candidate] -> [Listof Candidate]) -> void
  defp loop(name, voting_region, candidates, prioritize_cands, voting_strategy, event_registry) do
    receive do
      %AbstractRegistry{values: new_candidates, type: CandStruct} ->
        IO.puts "Voter #{name} has received candidates! #{inspect new_candidates}"
        loop(name, voting_region, new_candidates, prioritize_cands, voting_strategy, event_registry)
      {:ballot, eligible_candidates, vote_leader} ->
        voting_strategy.vote(name, candidates, eligible_candidates, vote_leader, prioritize_cands)
        loop(name, voting_region, candidates, prioritize_cands, voting_strategy, event_registry)
    end
  end
end

# A Voter that participates in the Caucus
defmodule RegularVoting do
  # Submit a vote for this voter's top preference candidate still in the race
  # Name [Setof Candidate] [Setof Candidate] PID ([Setof Candidate] -> [Setof Candidate]) -> void
  def vote(name, all_candidates, eligible_candidates, vote_leader, prioritize_cands) do
    candidate_prefs = prioritize_cands.(all_candidates)
    %CandStruct{name: voting_for, tax_rate: _, pid: _} = Enum.find(candidate_prefs, fn cand -> MapSet.member?(eligible_candidates, cand) end)
    IO.puts "Voter #{name} is voting for #{voting_for}!"
    send vote_leader, {:vote, name, voting_for}
  end
end

# A Voter that votes for multiple candidates
defmodule GreedyVoting do
  # Submit votes for multiple candidates in this voter's top preferences
  # Name [Setof Candidate] [Setof Candidate] PID ([Setof Candidate] -> [Setof Candidate]) -> void
  def vote(name, all_candidates, eligible_candidates, vote_leader, prioritize_cands) do
    candidate_prefs = prioritize_cands.(all_candidates)
    %CandStruct{name: voting_for, tax_rate: _, pid: _} = Enum.find(candidate_prefs, fn cand -> MapSet.member?(eligible_candidates, cand) end)
    %CandStruct{name: second_vote, tax_rate: _, pid: _} = Enum.find(candidate_prefs, fn cand -> MapSet.member?(eligible_candidates, cand) && cand.name != voting_for end)
    IO.puts "Greedy voter #{name} is voting for multiple candidates!"

    send vote_leader, {:vote, name, voting_for}
    if (second_vote) do
      send vote_leader, {:vote, name, second_vote}
    else
      send vote_leader, {:vote, name, voting_for}
    end
  end
end

defmodule StubbornVoting do
  # Submit a vote for the voter's top preference, even if that candidate isn't in the race
  # Name [Setof Candidate] [Setof Candidate] PID ([Setof Candidate] -> [Setof Candidate]) -> void
  def vote(name, all_candidates, _eligible_candidates, vote_leader, prioritize_cands) do
    candidate_prefs = prioritize_cands.(all_candidates)
    [%CandStruct{name: voting_for, tax_rate: _, pid: _} | _] = candidate_prefs 
    send vote_leader, {:vote, name, voting_for}
  end
end

defmodule SleepThroughVoting do
  # Doesn't issue a vote
  # 5 arguments -> void
  def vote(_, _, _, _, _) do
    :noop
  end
end

# The actor that manages voting and elects a winner
defmodule VoteLeader do
  defstruct [:pid]
  # initialize the VoteLeader
  # Region PID PID PID -> PID
  def spawn(region, candidate_registry, voter_registry, region_manager, deadline_time) do
    spawn fn -> 
      send Process.whereis(region), {:msg, self()}
      send voter_registry, {:voter_roll, self(), region}
      region_voters = receive_region_voters(deadline_time)
      Process.sleep(deadline_time - :os.system_time(:millisecond))
      setup_voting(MapSet.new(), region_voters, MapSet.new(), candidate_registry, region_manager)
    end
  end

  def receive_region_voters(deadline_time) do
    receive do
      %VoterRegistry{voters: new_region_voters} -> new_region_voters
    end
  end

  # Query for any prerequisite data for running a round of voting
  # [Setof Voter] PID -> void
  defp setup_voting(voters, region_voters, blacklist, candidate_registry, region_manager) do
    send candidate_registry, {:msg, self()}
    prepare_voting(voters, region_voters, MapSet.new(), blacklist, candidate_registry, region_manager)
  end

  # Gather the information necessary to start voting and issue votes to voters
  # [Setof Voter] [Setof Candidate] PID -> void
  defp prepare_voting(voters, region_voters, candidates, blacklist, candidate_registry, region_manager) do
    if !(Enum.empty?(voters) || Enum.empty?(candidates)) do
      valid_candidates = MapSet.difference(candidates, blacklist)
      issue_votes(voters, valid_candidates)
      voter_lookup = Enum.reduce(voters, %{}, fn voter, acc -> Map.put(acc, voter.name, voter) end)
      Process.send_after self(), :timeout, 1000

      vote_loop(
        %VoterData{voters: voters, region_voters: region_voters, lookup: voter_lookup, votes: %{}},
        %CandData{
          cands: valid_candidates, 
          lookup: Enum.reduce(valid_candidates, %{}, fn cand, acc -> Map.put(acc, cand.name, cand) end), 
          blacklist: blacklist, 
        },
        candidate_registry,
        region_manager
      )
    else
      receive do
        %AbstractRegistry{values: new_voters, type: VoterStruct} ->
          IO.puts "Vote leader received voters! #{inspect new_voters}"
          prepare_voting(new_voters, region_voters, candidates, blacklist, candidate_registry, region_manager)
        %AbstractRegistry{values: new_candidates, type: CandStruct} ->
          IO.puts "Vote Leader received candidates! #{inspect new_candidates}"
          prepare_voting(voters, region_voters, new_candidates, blacklist, candidate_registry, region_manager)
      end
    end
  end

  # Request a vote from all voters with the current eligible candidates
  # [Setof Voter] [Setof Candidate] PID -> void
  defp issue_votes(voters, candidates) do
    IO.puts "Issuing votes!"
    Enum.each(voters, fn %VoterStruct{name: _, pid: pid} -> send pid, {:ballot, candidates, self()} end)
  end

  # Receive votes from voters and elect a winner if possible
  # VoterData CandData PID PID -> void
  defp vote_loop(voter_data, cand_data, cand_registry, region_manager) do
    if MapSet.size(voter_data.voters) == Kernel.map_size(voter_data.votes) do
      conclude_vote(voter_data, cand_data, cand_registry, region_manager)
    else
      receive do
        :timeout ->
          conclude_vote(voter_data, cand_data, cand_registry, region_manager)
        {:vote, voter_name, cand_name} -> 
          cond do
            # CASE 1: Already eliminated Voter or Voter in wrong region
            !Map.has_key?(voter_data.lookup, voter_name) || !Enum.any?(voter_data.region_voters, fn voter -> voter == voter_name end) ->
              vote_loop(voter_data, cand_data, cand_registry, region_manager)
            # CASE 2: Stubborn Voter || CASE 3: Greedy Voter
            !Map.has_key?(cand_data.lookup, cand_name) || Map.has_key?(voter_data.votes, voter_name) ->
              IO.puts "Voter #{inspect voter_name} has been caught trying to vote for a dropped candidate!"

              vote_loop(
                %VoterData{
                  voters: MapSet.delete(voter_data.voters, voter_data.lookup[voter_name]),
                  region_voters: voter_data.region_voters,
                  lookup: Map.delete(voter_data.lookup, voter_name),
                  votes:  Map.delete(voter_data.votes, voter_name)
                },
                cand_data,
                cand_registry,
                region_manager
              )
            # CASE 4: Voter checks out
            true ->
              IO.puts "Voter #{inspect voter_name} is voting for candidate #{inspect cand_name}!"
              new_voting_record = Map.put(voter_data.votes, voter_name, cand_name)

              vote_loop(
                %{voter_data | votes: new_voting_record},
                cand_data,
                cand_registry, 
                region_manager
              )
          end
      end
    end

  end

  # Determine a winner, or if there isn't one, remove a loser and start next voting loop
  # VoterData CandData PID PID -> void
  defp conclude_vote(voter_data, cand_data, cand_registry, region_manager) do
    initial_tally = Enum.reduce(cand_data.cands, %{}, fn %CandStruct{name: cand_name, tax_rate: _, pid: _}, init -> Map.put(init, cand_name, 0) end)
    tally = Enum.reduce(voter_data.votes, initial_tally, fn {_, cand_name}, curr_tally -> Map.update!(curr_tally, cand_name, &(&1 + 1)) end)

    confirmed_voters = Enum.reduce(voter_data.votes, MapSet.new, fn {voter_name, _}, acc -> MapSet.put(acc, voter_data.lookup[voter_name]) end)
    num_votes = Enum.reduce(tally, 0, fn {_, count}, acc -> acc + count end)
    {frontrunner, their_votes} = Enum.max(tally, fn {_, count1}, {_, count2} -> count1 >= count2 end)
    IO.puts "The frontrunner received #{their_votes} votes, out of #{num_votes} total votes"
    if their_votes > (num_votes / 2) do
      send region_manager, {:caucus_winner, frontrunner}
    else
      {loser, _} = Enum.min(tally, fn {_, count1}, {_, count2} -> count1 <= count2 end)
      Enum.each(cand_data.cands, fn %CandStruct{name: _, tax_rate: _, pid: pid} -> send pid, {:tally, tally} end)
      %CandStruct{name: _, tax_rate: _, pid: losing_pid} = cand_data.lookup[loser]
      send losing_pid, :loser
      IO.puts "Our loser is #{loser}!"

      setup_voting(confirmed_voters, voter_data.region_voters, MapSet.put(cand_data.blacklist, cand_data.lookup[loser]), cand_registry, region_manager)
    end
  end
end

defmodule EventRegistry do
  def spawn do
    spawn fn -> loop(%{}) end
  end

  defp loop(events) do
    receive do
      {:register_evt, key, val} ->
        loop(Map.put(events, key, val))
      {:get_evt_time, key, pid} ->
        send pid, {:event_time, Map.get(events, key)}
        loop(events)
    end
  end
end

# Aggregates the results of many caucuses to determine a winner for a region
defmodule RegionManager do
  def spawn(regions, candidate_registry, voter_registry, event_registry) do
    spawn fn ->
      curr_time = :os.system_time(:millisecond)
      reg_deadline = curr_time + 1000
      doors_close = curr_time + 2000

      send event_registry, {:register_evt, :registration_deadline, reg_deadline}
      send event_registry, {:register_evt, :doors_close, doors_close}

      send_registration_info(reg_deadline, regions, voter_registry)
      initialize_regions(regions, candidate_registry, voter_registry, doors_close)
      determine_region(regions, %{})
    end
  end

  def send_registration_info(deadline_time, regions, voter_registry) do
    Process.send_after self(), :deadline, deadline_time - :os.system_time(:millisecond)
    send voter_registry, {:registration_info, deadline_time, regions}
  end

  def initialize_regions(regions, candidate_registry, voter_registry, deadline_time) do
    receive do
      :deadline ->
        for region <- regions do
          VoteLeader.spawn(region, candidate_registry, voter_registry, self(), deadline_time)
        end
    end
  end

  def determine_region(regions, results) do
    receive do
      {:caucus_winner, cand_name} ->
        new_results = Map.update(results, cand_name, 1, &(&1 + 1))
        total_results = Enum.reduce(new_results, 0, fn {_, count}, acc -> acc + count end)

        if length(regions) == total_results do
          {victor_name, _} = Enum.max(new_results, fn {_, count1}, {_, count2} -> count1 >= count2 end)
          IO.puts "The winner of the region is: #{inspect victor_name}!"
        else
          determine_region(regions, new_results)
        end
    end
  end
end

defmodule StupidSort do
  def generate(cand_names) when is_list(cand_names) do
    fn candidates ->
      Enum.reduce(Enum.reverse(cand_names), Enum.sort(candidates), fn cand_name, acc -> new_candidates(cand_name, acc) end)
    end
  end

  def generate(cand_name) do
    fn candidates -> new_candidates(cand_name, Enum.sort(candidates)) end
  end

  defp new_candidates(cand_name, candidates) do
    candidate? = Enum.find(candidates, fn(%CandStruct{name: n, tax_rate: _, pid: _}) -> n == cand_name end)
    if candidate? do
      [candidate? | Enum.reject(candidates, fn(%CandStruct{name: n, tax_rate: _, pid: _}) -> n == cand_name end)]
    else
      candidates
    end
  end
end

defmodule MockSubscriber do
  def mock_spawn(pubsub) do
    spawn fn -> 
      send pubsub, {:subscribe, self()}
      loop()
    end
  end

  defp loop do
    receive do
      any -> IO.puts inspect(any)
    end
  end
end

defmodule SuicidalSubscriber do
  def mock_spawn(pubsub) do
    spawn fn ->
      send pubsub, {:subscribe, self()}
      Process.exit(self(), :kill)
    end
  end
end
