#lang syndicate/actor

(provide voter vote round candidate candidate-name tally elected winner)

;; a Name is a (caucus-unique) String

;; an ID is a unique Symbol

;; a TaxRate is a Number

;; a Threshold is a Number

;; a VoteCount is a Number

;; a Region is a (caucus-unique) String

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

;; There are four actor roles:
;; - Caucus Leaders
;; - Candidates
;; - Voters
;; - Region Manager

;; There are two presence-oriented conversations:
;; Voters announce their presence through a Voter assertion
;; Candidates announce their presence through a Candidate assertion

;; There is a conversation about voting:

;; The Caucus Leader initiates a round of voting by making a Round assertion
;; with a new ID and the list of candidates still in the running. Voters vote in
;; a certain round by making a Vote assertion with the corresponding round ID,
;; their name, and the name of the candidate they are voting for. The Leader then
;; makes a RoundInfo assertion to announce the results of that round of voting,
;; containing the Voters eligible to vote in that round, the Candidates eligible
;; to be voted for, the number of votes received by each candidate, and the outcome
;; of that round.

;; There is an election results conversation, where the Caucus Leader announces
;; the winner with an Elected assertion

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
