#lang syndicate/actor

(provide ballot ballot-voter participating vote round candidate candidate-name tally elected winner voter-roll register change-reg unregister registration-deadline doors-opened doors-close registration-open reg-fail valid-voters audited-round valid-vote valid-vote? unregistered-voter not-participating-voter multiple-votes ineligible-candidate banned-voter)

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

;; a ValidVoters is a (valid-voters Region [Set-of Name])
(assertion-struct valid-voters (region names))

;; an AuditedRound is an (audited-round ID Region [List-of InvalidBallot])
(assertion-struct audited-round (round-id region ballots))

;; a ValidVote is a (valid-vote Name Name)
(assertion-struct valid-vote (voter cand))

;; an AuditedBallot is one of:
;; - a ValidVote
;; - an InvalidBallot

;; an InvalidBallot is one of:
;; - UnregisteredVoter
;; - NotParticipatingVoter
;; - MultipleVotes
;; - IneligibleCandidate
;; - BannedVoter

;; an UnregisteredVoter is an (unregistered-voter Name)
(assertion-struct unregistered-voter (name))

;; a NotParticipatingVoter is a (not-participating-voter Name)
(assertion-struct not-participating-voter (name))

;; a MultipleVotes is a (multiple-votes Name [List-of Ballot])
(assertion-struct multiple-votes (name ballots))

;; an IneligibleCandidate is an (ineligible-candidate Name Name)
(assertion-struct ineligible-candidate (voter cand))

;; a BannedVoter is a (banned-voter Name InvalidBallot)
(assertion-struct banned-voter (name vote))

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

;; There is a conversation about auditing:
;; There is an Auditor in a region that notifies a Client of illegal activity by voters in that region.
;; When doors close for participation in the vote in a Region, the Client expresses interest in ValidVoters assertion,
;; providing the region and expecting a set of Names of voters that are trying 


;; TODO best way of articulating the `Auditor replies as if...` idea?
;; There is an Auditor in a region that notifies a Client of illegal activity by voters in that region.
;; When doors close for participation in the vote in a Region, the Client expresses interest in a ValidVoters assertion,
;; providing the region of the Auditor, and expecting a set of Names of voters that are both participating and registered
;; to vote. The Auditor provides this information as if doors have closed for participation in the Auditor's region.
;; When the Client expresses interest in an AuditedRound assertion, providing the region of the Auditor and the ID of a 
;; round of voting and expecting a set of InvalidBallots, the Auditor responds with the expected assertion, as if the
;; round of voting has ended.
;; In practice, the Client is the Vote Leader for the Region, and there is one Auditor per region.

;; A Ballot passes the Auditor's inspection if all of the following are true:
;; 1. The voter is registered to vote in the region the ballot was received in
;; 2. The voter is participating in the vote managed by the vote leader
;; 3. The voter only submits one ballot per round (and if multiple ballots were submitted, all are thrown out)
;; 4. The voter votes for a candidate still in the race in that region
;; 5. The voter has not violated any of the above in any previous round

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

