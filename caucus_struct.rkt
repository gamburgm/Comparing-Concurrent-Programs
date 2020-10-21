#lang syndicate/actor

(provide ballot ballot-voter participating vote round candidate candidate-name tally elected winner voter-roll register change-reg unregister registration-deadline doors-opened doors-close registration-open reg-fail valid-votes)

;; a Name is a (caucus-unique) String

;; an ID is a unique Symbol

;; a TaxRate is a Number

;; a Threshold is a Number

;; a VoteCount is a Number

;; a Region is a (caucus-unique) String

;; a Time is a Number (number of milliseconds in Unix time)

;; a Ballot is a (ballot Name Name)
(assertion-struct ballot (voter cand))

;; a Participating is a (participating Name Region)
(assertion-struct participating (name region))

;; a Vote is a (voter Name ID Region Name), where the first name is the voter and the
;; second is who they are voting for
(assertion-struct vote (voter round region candidate))

;; a Round is a (round ID Region (Listof Name))
(assertion-struct round (id region candidates))

;; a Candidate is a (candidate Name TaxRate Threshold)
(assertion-struct candidate (name tax-rate))

;; a Tally is a (tally Name Region VoteCount)
(assertion-struct tally (name region vote-count))

;; an Elected is a (elected Name Region)
(assertion-struct elected (name region))

;; a Winner is a (winner Name)
(assertion-struct winner (name))

;; a VoterRoll is a (voter-roll Region [Setof Name])
(assertion-struct voter-roll (region voters))

;; a Register is a (register Name Region)
(assertion-struct register (name region))

;; a ChangeRegistration is a (change-reg Name Reg)
(assertion-struct change-reg (name region))

;; a RegistrationDeadline is a (registration-deadline Time)
(assertion-struct registration-deadline (deadline))

;; a DoorsOpened is a (doors-opened Time)
(assertion-struct doors-opened (time region))

;; a DoorsClose is a (doors-close Time)
(assertion-struct doors-close (at region))

;; an Unregister is an (unregister Name)
(assertion-struct unregister (name))

;; a RegistrationOpen is a (registration-open)
(assertion-struct registration-open ())

;; a RegistrationFailure is a (reg-fail Name)
(assertion-struct reg-fail (name))

;; an InvalidVotes is an (invalid-votes ID Region [List-of Ballot])
(assertion-struct valid-votes (round-id region ballots))

;; There are five actor roles:
;; - Caucus Leaders
;; - Candidates
;; - Voters
;; - Voter Registry
;; - Region Manager

;; There is a conversation about deadlines:
;; There are two deadlines that affect participants in the election. The first is for registration, which is announced
;; by the Region Manager with a RegistrationDeadline assertion. The second is for participation in the election, which
;; is announced independently by the Vote Leader for each region with a DoorsClose assertion.

;; There is a conversation about registration:
;; The Voter Registry announces that registration has opened with a RegistrationOpen assertion. Voters register by sending
;; a Register message with the voter's name and registering region. Registration succeeds if the voter hasn't registered
;; before, and otherwise fails. Voters change their registration by sending a ChangeRegistration message with their name
;; and registering region, which succeeds if the voter has registered before, but otherwise fails. Voters unregister by
;; sending an Unregister message with their name, which succeeds if they have registered before, and otherwise fails. 
;; If an attempt to change a voter's registration status fails, the Voter Registry sends a RegistrationFailure message
;; with the name of the voter and the message that failed. A request to change registration status only takes effect
;; for an upcoming election if it is received prior to the registration deadline. 
;; After the deadline, Vote Leaders express interest in VoterRoll assertions, containing the voters registered in
;; their region. The Voter Registry replies with the requested VoterRoll assertion.

;; There are two conversations about participation:
;; Voters who have registered announce their interest in participating in their local caucus with a Participating assertion.
;; Candidates announce that they are eligible to win the election with a Candidate assertion.

;; There is a conversation about voting:
;; The Caucus Leader initiates a round of voting by making a Round assertion
;; with a new ID and the list of candidates still in the running. Voters vote in
;; a certain round by making a Vote assertion with the corresponding round ID,
;; their name, and the name of the candidate they are voting for.

;; NOTE shouldn't mention the Vote Leader. There's an Auditor and somebody who wants something audited.
;; NOTE should be sets, not lists
;; There is a conversation about auditing:
;; Each region contains an Auditor who presides over the caucus and highlights any suspicious
;; or illegal activity in the voting process.
;; The Auditor determines the voters registered to vote in a region by expressing interest in
;; a VoterRoll assertion, which contains a list of Names of registered voters.
;; Upon doors closing in a caucus, Vote Leaders express interest in a VoterVerification
;; assertion containing the Vote Leader's region, the Vote Leader's list of all participating
;; voters, and a list of all voters deemed invalid. The Auditor responds with the anticipated
;; assertion.
;; NOTE unclear which parts of the request are provided by the Vote Leader and which parts is it pattern-matching
;; Similarly, after a round of voting, Vote Leaders express interest in a VoteVerification assertion,
;; containing the Leader's region, the ID of the current round of voting, the Leader's list of
;; received votes, and a list of all votes deemed invalid. The Auditor responds with the anticipated
;; assertion.

;; There is a conversation about the winner for a region.
;; A Vote Leader declares the winner for their region with an Elected assertion including
;; the name of the candidate and the name of the region the elected candidate won. The Region
;; Manager declares whichever candidate has received the most votes the winner with a
;; Winner assertion.

;; There are multiple bad actors.
;; - Stubborn Candidate: a candidate who tries to re-enter the race after having been dropped
;; - Greedy Voter: A voter that tries voting twice when possible.
;; - Stubborn Voter: A voter that always votes for the same candidate, even if that candidate isn't eligible.
;; - Late-Joining Voter: A voter who joins voting late (i.e. isn't available to vote for the first round).
;; - Unregistered Voter: A voter who votes without being registered to vote.

