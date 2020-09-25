########################### Conversations ###########################
### Structs/Messages ###
# a Name is a String
# a TaxRate is a Number
# a PID is a Process ID
# a Threshold is a Number
# a Region is a String
# a Time is a number (milliseconds in Unix time)
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
# a CloseAt is a {:close_at, Time}
#
# Messages regarding Voter Registration:
# a RegistrationInfo is a {:registration_info, Time, [Listof Region]}
# a RegistrationDeadline is a {:registration_deadline, PID}
# a Register is a %Register{name: Name, region: Region}
# a ChangeRegistration is a %ChangeReg{name: Name, region: Region, pid: PID}
# a VoterRegistry is a %VoterRegistry{voters: [Setof Voter]}
# a VoterRoll is a %VoterRoll{region: Region, pid: PID}
#
#
# a VotingStrategy is a Module with a function that contains a `vote` function with the signature:
#   Name [Setof Candidate] [Setof Candidate] PID ([Setof Candidate] -> [Setof Candidate]) -> void
#
# There are X types of conversations:
# 1. Presence oriented conversations
# 2. Voting registration conversations
# 3. Voting conversations
#
# There are 7 sets of actors participating in conversations:
# 1. Voters
# 2. Candidates
# 3. Vote Leader
# 4. Candidate Registry
# 5. Participation Registry
# 6. Voter Registry
# 7. Region Manager
#
# There is a presence-oriented conversation:
# 1. Candidates announce themselves as eliglble to vote to the candidate registry.
#
# There is a conversation about voter registration:
# 1. The region manager tells the voter registry when the registration deadline is and what regions are open for registration.
# 2. The Voter Registry holds the following conversations and responds in kind:
#     a. Voters express interest in registering to the voter registry if they haven't yet registered.
#     b. Voters may change their registration if they have already registered.
#     c. Voters may request the time registration will close.
# 3. Upon registration closing, the Voter Registry will listen to requests for the Voter Roll of voters in a region and respond with the requested information.
#
# There is a conversation about voting:
# 1. Vote leaders request the voters eligible to vote in their region from the Voter Registry.
# 2. Upon receiving that information, they alert all voters in their region that doors have opened and what time doors will closed (at which point new 
#    participants will be turned away).
# 3. Voters express interest in participating in the election in their region to their local Participation Registry.
# 4. After doors have closed, the Vote Leader requests the participating voters in the region from the Participation Registry and all eligible candidates from
#    the Candidate Registry.
# 5. The Vote Leader sends ballots to all voters, containing the list of all currently eligible candidates.
# 6. Voters submit a vote with their preferred candidate.
# 7. If one candidate receives a 50%> majority of the vote, that candidate wins that region and that information is sent to the Region Manager. Otherwise,
#    the candidate with the fewest votes is eliminated from the race, and new ballots are sent to the participating voters.

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

defmodule Unregister do
  defstruct [:name]
end

defmodule VoterRoll do
  defstruct [:pid, :region]
end

