########################### Conversations ###########################
### Structs/Messages ###
# a Name is a String
# a TaxRate is a Number
# a PID is a Process ID
# a Threshold is a Number
# a Region is a String
#
# a Candidate is a %CandStruct{name: Name, tax_rate: TaxRate, pid: PID}
# a Voter is a %VoterStruct{name: Name, pid: PID}
# a Subscription is a {:subscribe, PID}
# a Ballot is a {:ballot, [Setof Candidate], PID}
# a Vote is a {:vote, Name, Name}
# a VoteLeader is a %VoteLeader{pid: PID}
# a Tally is a {:tally, [Mapof Name -> Number]}
# a CaucusWinner is a {:caucus_winner, Name}
# a Loser is a :loser
# an AbstractRegistry response is a %AbstractRegistry{values: [Setof X], type: X}
#
# a VotingStrategy is a Module with a function that contains a `vote` function with the signature:
#   Name [Setof Candidate] [Setof Candidate] PID ([Setof Candidate] -> [Setof Candidate]) -> void

# a CandData is a %CandData{cands: [Setof CandStruct], lookup: [Mapof Name -> CandStruct], blacklist: [Setof CandStruct]}
# CandData represents the status of Candidates during a Vote
defmodule CandData do
  defstruct [:cands, :lookup, :blacklist]
end

# a VoterData is a %VoterData{voters: [Setof VoterStruct], lookup: [Mapof Name -> VoterStruct], votes: [Mapof Name -> Name]}
# VoterData represents the status of Voters during a Vote
defmodule VoterData do
  defstruct [:voters, :region_voters, :lookup, :votes]
end

# A Candidate registered for election in the Caucus
defmodule CandStruct do
  defstruct [:name, :tax_rate, :pid]
end

defmodule Register do
  defstruct [:name, :region]
end

defmodule ChangeReg do
  defstruct [:name, :region]
end

defmodule VoterRoll do
  defstruct [:pid, :region]
end
