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
# a Register is a {:register, Name, Region}
# a ChangeRegistration is a {:change_reg, Name, Region}
# an Unregister is a {:unregister, name}
# a VoterRoll is a {:voter_roll, PID, Region}
#
# Messages regarding Voter Registration:
# a RegistrationInfo is a {:registration_info, Time, [Listof Region]}
# a RegistrationDeadline is a {:registration_deadline, PID}
# a Register is a {:register, Name, Region}
# an Unregister is a {:unregister, Name}
# a ChangeRegistration is a {:change_reg, Name, Region}
# a VoterRegistry is a %VoterRegistry{voters: [Setof Voter]}
# a VoterRoll is a %VoterRoll{region: Region, pid: PID}
#
# Messages regarding Pub-Sub:
# a Publish is a {:publish, PID, Any}
# a Subscribe is a {:subscribe, PID}
# a Message is a {:msg, PID}
# a Remove is a {:remove, PID}
#
# a VotingStrategy is a Module with a function that contains a `vote` function with the signature:
#   Name [Setof Candidate] [Setof Candidate] PID ([Setof Candidate] -> [Setof Candidate]) -> void
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
# There are Publish-Subscribe conversations.
# The roles are a server, publishers, and subscribers. Publishers publish information to the server with a Publish message containing
# the PID of the Publisher and the data they would like to publish. That information can be withdrawn by the publisher with a Remove
# message, containing the PID of the publisher. Subscribers can retrieve this information with a Message message, containing the
# PID of the subscriber, to which the server will respond with a Payload containing the set of information published to the server.
# Subscribers may also send a Subscribe message with their PID, the consequence of which is that a Payload message will be sent to
# subscribers whenever a publisher publishes new data or withdraws their data.
# There are two Publish-Subscribe conversations:
# - A Candidate Registry (server) tracks eligible candidates (publishers) for voters and vote leaders (subscribers) to view.
# - a Participation Registry (server) tracks voters (publishers) interested in voting in the election for the vote leaders (subscribers) running the vote in their region.
#
# There is a conversation about voter registration:
# Voters register to vote in a region with a Register message containing their name and the region they'd like to vote in. Registration
# succeeds if the Voter was not previously registered, and fails otherwise. Voters can also change which region they're registered to
# vote in with a ChangeRegistration message with their name and the state they'd like to be registered in, which succeeds if the voter
# was already registered, but otherwise fails. Voters can unregister with an Unregister message, which succeeds if the voter is registered,
# but otherwise fails. Conversations to change the registration status of a voter take effect for the upcoming election only if received prior
# to the registration deadline.
# After the deadline has passed, Vote Leaders request the voters registered in their region with a VoterRoll message, and receive the desired
# information as a VoterRegistry message.
#
# There is a conversation about voting:
# Vote leaders initiate voting with a Ballot message containing the list of candidates still in the race to participating voters. Voters
# reply with a Vote message containing their name and the name of the Candidate they would like to vote for. If > 50% of voters vote
# for one candidate, then that candidate wins the region. Otherwise, the candidate with the fewest votes is removed from the set
# of eligible candidates and a new Ballot with one fewer candidate is sent to voters in a new round of voting.

# a CandData is a %CandData{cands: [Setof CandStruct], lookup: [Mapof Name -> CandStruct], blacklist: [Setof CandStruct]}
# CandData represents the status of Candidates during a Vote
defmodule CandData do
  defstruct [:cands, :lookup, :blacklist]
end

# a VoterData is a %VoterData{voters: [Setof VoterStruct], lookup: [Mapof Name -> VoterStruct], votes: [Mapof Name -> Name]}
# VoterData represents the status of Voters during a Vote
defmodule VoterData do
  defstruct [:voters, :lookup, :votes]
end

# A Candidate registered for election in the Caucus
defmodule CandStruct do
  defstruct [:name, :tax_rate, :pid]
end

