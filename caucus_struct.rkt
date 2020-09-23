#lang syndicate/actor

(provide voter vote round candidate candidate-name tally elected winner voter-roll registration-close)

;; a Name is a (caucus-unique) String

;; an ID is a unique Symbol

;; a TaxRate is a Number

;; a Threshold is a Number

;; a VoteCount is a Number

;; a Region is a (caucus-unique) String

;; a Time is a Number (number of milliseconds in Unix time)

;; a Voter is a (voter Name Region)
(assertion-struct voter (name region))

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
(assertion-struct doors-opened (time))

;; a DoorsClose is a (doors-close Time)
(assertion-struct doors-close (at))

;; There are four actor roles:
;; - Caucus Leaders
;; - Candidates
;; - Voters
;; - Region Manager

;; There are two presence-oriented conversations:
;; Voters announce their presence through a Voter assertion
;; Candidates announce their presence through a Candidate assertion

;; There is a conversation about registration:
;; The Region Manager initializes a Voter Registry to keep track of the 
;; voter roll in each region. Registration opens in a time window prior
;; to voting beginning, where voters may freely change which region they're
;; registered in, enforcing that they are only registered in one location at a time
;; (where they registered most recently). 
;; To participate in the Caucus, a voter must both register in the Voter
;; Registry, and announce that they are participating in voting through
;; a `voter` assertion with their name and the correct registered region.

;; There is a conversation about voting:

;; The Caucus Leader initiates a round of voting by making a Round assertion
;; with a new ID and the list of candidates still in the running. Voters vote in
;; a certain round by making a Vote assertion with the corresponding round ID,
;; their name, and the name of the candidate they are voting for.

;; There is a conversation about the winner for a region. Each region is identified by
;; a name that voters explicitly register for. When a candidate is elected by a caucus,
;; they announce the election of that candidate and alert the region manager, who then
;; closes voting and declares a final winner when one of the candidates has received 
;; a plurality of the votes.

;; There are multiple bad actors.
;; - Stubborn Candidate: a candidate who tries to re-enter the race after having been dropped --> could be implemented differently than the way I have it now
;; - Greedy Voter: A voter that tries voting twice when possible.
;; - Stubborn Voter: A voter that always votes for the same candidate, even if that candidate isn't eligible.
;; - Late-Joining Voter: A voter who joins voting late (i.e. isn't available to vote for the first round).
;; - Unregistered Voter: A voter who votes without being registered to vote.

