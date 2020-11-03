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
# an AuditedBallot is one of:
# - a ValidVote
# - an InvalidBallot
#
# a ValidVote is a {:valid_vote, [Name of Voter], [Name of Candidate]}
#
# an InvalidBallot is one of:
# - UnregisteredVoter
# - NotParticipatingVoter
# - MultipleVotes
# - IneligibleCandidate
# - FailedToVote
# - BannedVoter
#
# an UnregisteredVoter is an {:unregistered_voter, Name}
# a NotParticipatingVoter is a {:not_participating_voter, Name}
# a MultipleVotes is a {:multiple_votes, Name, [List-of Ballot]}
# an IneligibleCandidate is an {:ineligible_cand, [Name of Voter], [Name of Candidate]}
# a FailedToVote is a {:failed_to_vote, Name}
# a BannedVoter is a {:banned_voter, Name, InvalidBallot}
#
# Messages regarding Auditing:
# an AuditVoters is an {:audit_voters, PID, [Set-of Name]}
# an InvalidatedVoters is an {:invalidated_voters, [Set-of Name]}
# an AuditBallots is an {:audit_ballots, PID, [Set-of Name], [Set-of Name]}
# an InvalidatedBallots is an {:invalidated_ballots, [Set-of Name]}
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
#
# There is a conversation about auditing:
# There is an Auditor in a region that responds to Client requests to validate information regarding an election in that region.
# The Client sends an AuditVoters message containing a set of Names representing voters. The Auditor responds with
# an InvalidatedVoters message contianing the set of Nmaes of voters not registered to vote in that region, acting as if
# the doors have closed for participation in that region.
# The Client sends the auditor an AuditBallots message containing a list of Ballots. the Auditor responds with
# an InvalidatedBallots message, containing a list of InvalidBallots that violate a rule in the voting process, and
# acting as if a round of voting has just ended.
# Each region contains one Auditor where the client is the region's Vote Leader.
#
# In order for a ballot to be counted and not be tossed out, all of the following must be true:
# - The voter must be registered to vote in the region that the ballot was received in
# - The voter must be participating in the vote managed by the vote leader
# - The voter must only submit one ballot total (if more are submitted, all ballots are thrown out)
# - The voter must be voting for a candidate that is still in the race
# - The voter has voted successfully in every round so far
# - The voter must not have violated any of these rules at any prior vote during this caucus
#
# The auditor is responsible for alerting the Vote Leader in the auditor's region about suspicious or illegal activity
# that occurs in the duration of the caucus.
#

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

