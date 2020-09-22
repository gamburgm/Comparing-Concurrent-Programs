#lang racket

(provide candidate candidate-name candidate-results-chan drop-out loser voter voter-name voter-voting-chan request-msg request-voters request-vote vote ballot-results all-candidates all-voters declare-leader declare-manager declare-winner publish withdraw subscribe message payload)

;; a Name is a string

;; a Tax-Rate is a number

;; a Threshold is a number

;; a Chan is a channel

;; a Region is a string

;; a Time is a number (milliseconds in Unix time)

;; a Candidate is a (candidate Name Tax-Rate Chan)
(struct candidate (name tax-rate results-chan) #:transparent)

;; a DropOut is a (drop-out Name)
(struct drop-out (name) #:transparent)

;; a Loser is a (loser Name)
(struct loser (name) #:transparent)

;; a Voter is a (voter Name Region Chan)
(struct voter (name region voting-chan) #:transparent)

;; a Request-Msg is a (request-msg Chan)
(struct request-msg (chan) #:transparent)

;; a RequestVoters is a (request-voters Region Chan)
(struct request-voters (region leader-chan) #:transparent)

;; a Request-Vote is a (request-vote Chan)
(struct request-vote (candidates chan) #:transparent)

;; a Vote is a (vote Name Name)
(struct vote (name candidate) #:transparent)

;; a ballot-results is a (ballot-results (Hashof Name . number))
(struct ballot-results (votes) #:transparent)

;; an All-Candidates is a (all-candidates [Setof Candidate])
(struct all-candidates (candidates) #:transparent)

;; an All-Voters is a (all-voters [Setof Voter])
(struct all-voters (voters) #:transparent)

;; a DeclareLeader is a (declare-leader Region Chan)
(struct declare-leader (region manager-comm-chan) #:transparent)

;; a DeclareManager is a (declare-manager Chan)
(struct declare-manager (results-chan) #:transparent)

;; a DeclareWinner is a (declare-winner Name)
(struct declare-winner (candidate) #:transparent)

;;;;; REGISTRY STRUCTS ;;;;;

;; a Publish is a (publish Any)
(struct publish (val) #:transparent)

;; a Withdraw is a (withdraw Any)
(struct withdraw (val) #:transparent)

;; a Subscribe is a (subscribe Chan)
(struct subscribe (subscriber-chan) #:transparent)

;; a Message is a (message Chan)
(struct message (response-chan) #:transparent)

;; a Payload is a (payload [Setof Any])
(struct payload (data) #:transparent)

;;;;;; VOTER REGISTRY STRUCTS ;;;;;

;; a Start is a (start)
(struct start () #:transparent)

;; a Register is a (register Name Region Chan)
(struct register (name region recv-chan) #:transparent)

;; a ChangeReg is a (change-reg Name Region Chan)
(struct change-reg (name region recv-chan) #:transparent)

;; a VoterRoll is a (voter-roll Chan Region)
(struct voter-roll (recv-chan region) #:transparent)

;; a ManagerComm is a (manager-comm Chan)
(struct manager-comm (chan) #:transparent)

;; a RegistrationConfig is a (registration-config Time (Listof Region))
(struct registration-config (deadline regions) #:transparent)

;; a RegistrationDeadline is a (registration-deadline Chan)
(struct registration-deadline (chan) #:transparent)

;; a RegistrationDeadlineTime is a (reg-deadline-time Time)
(struct reg-deadline-time (time) #:transparent)

;; a DoorsClose is a (doors-close-at Time)
(struct doors-close-at (time) #:transparent)

;;;; ENTITIES ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; 1. Candidates        
;; 2. Candidate Registry
;; 3. Voters            
;; 4. Voter/Participation Registry    
;; 5. Vote Leader       
;; 6. Region Manager
;; 7. Voter Registry
;; 

;;;; CONVERSATIONS ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Publish Conversations
;; 1. Candidates publish their information to the Candidate Registry through a `candidate` struct sent to the Registry's channel
;; 2. Voters publish their information to their region's Participation Registry through a `voter` struct sent to the Registry's channel
;; 3. Candidates can remove themselves from eligibility by sending a `drop-out` struct to the Candidate Registry
;;     -> This occurs when the candidate receives a number of votes below the candidate's threshold for staying in the race.
;; 4. Vote Leaders publish their information to the Region Manager through a `declare-leader` struct
;; 5. Voters publish their preferred voting region to a Voter Registry by sending a  `register` message to register and a `change-reg` message to change registration.
;;
;; Subscribe Conversations
;; 1. Voters subscribe to the Candidate Registry to receive the most up-to-date list of available Candidates whenever a candidate registers.
;; 2. The Vote Leader subscribes to the Candidate Registry to receive the same information that voters do.
;; 
;; Message Conversations
;; 1. The Vote Leader sends a `request-msg` struct to the Voter Registry to receive the most up-to-date list of current voters.
;; 2. The Vote Leader sends a `request-msg` struct to the Candidate Registry to receive the most up-to-date list of available candidates.
;;
;; Voting Conversations
;; 1. The Voting Leader sends every Voter (through their `voter` struct) a request to vote through the `request-vote` struct, sending a List of valid candidate names.
;; 2. Voters reply by picking a name to vote for and sending the Vote Leader a `vote` struct.
;; 3. If one candidate has received a majority of votes, then that candidate is elected. If not, the least voted for candidate is removed, and voting begins again.
;; 4. At the end of every round of voting, the ballot-results of votes is sent to every Candidate.
;; 5. When a candidate wins an election, the Vote Leader publishes that information to the Region Manager. When all caucuses have reported, the majority winner is elected.
;;
;; Voter Registry Conversation
;; 1. The Voter Registry signals to the Region Manager that voting begin after registration has finished.
;; 2. The Vote Leaders query the Voter Registry for the list of all valid voters in their region.

