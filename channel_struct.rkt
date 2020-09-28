#lang racket

(provide candidate candidate-name candidate-results-chan drop-out loser voter voter-name voter-voting-chan request-msg request-voters request-vote vote ballot-results all-candidates all-voters declare-leader declare-manager declare-winner publish withdraw subscribe message payload)

;;;;;;; CONSTANTS ;;;;;;;
(define REG-DEADLINE-NAME 'registration-deadline)
(define DOORS-CLOSE-NAME 'doors-close)

;;;;;;; TYPES ;;;;;;;;;;;
;; a Name is a string

;; a Tax-Rate is a number

;; a Threshold is a number

;; a Chanof is a channel of some struct or of a union of structs

;; a Region is a string

;; a Time is a number (milliseconds in Unix time)

;; CandidateResults is (Union Loser BallotResults)

;; a Candidate is a (candidate Name Tax-Rate [Chanof CandidateResults])
(struct candidate (name tax-rate results-chan) #:transparent)

;; a DropOut is a (drop-out Name)
(struct drop-out (name) #:transparent)

;; a Loser is a (loser Name)
(struct loser (name) #:transparent)

;; a Voter is a (voter Name Region [Chanof RequestVote])
(struct voter (name region voting-chan) #:transparent)

;; a RequestVote is a (request-vote [Chanof Vote])
(struct request-vote (candidates chan) #:transparent)

;; a Vote is a (vote Name Name)
(struct vote (name candidate) #:transparent)

;; a BallotResults is a (ballot-results (Hashof Name . number))
(struct ballot-results (votes) #:transparent)

;; an AllCandidates is a (all-candidates [Setof Candidate])
(struct all-candidates (candidates) #:transparent)

;; an AllVoters is a (all-voters [Setof Voter])
(struct all-voters (voters) #:transparent)

;; a DeclareWinner is a (declare-winner Name)
(struct declare-winner (candidate) #:transparent)

;;;;; ABSTRACT REGISTRY STRUCTS ;;;;;

;; a Publish is a (publish Any)
(struct publish (val) #:transparent)

;; a Withdraw is a (withdraw Any)
(struct withdraw (val) #:transparent)

;; a Subscribe is a (subscribe [Chanof Payload])
(struct subscribe (subscriber-chan) #:transparent)

;; a Message is a (message [Chanof Payload])
(struct message (response-chan) #:transparent)

;; a Payload is a (payload [Setof Any])
(struct payload (data) #:transparent)

;;;;;; VOTER REGISTRY STRUCTS ;;;;;

;; a Register is a (register Name Region)
(struct register (name region) #:transparent)

;; a ChangeReg is a (change-reg Name Region)
(struct change-reg (name region) #:transparent)

;; an Unregister is an (unregister Name)
(struct unregister (name) #:transparent)

;; a VoterRoll is a (voter-roll [Chanof Payload] Region)
(struct voter-roll (recv-chan region) #:transparent)

;; a RegistrationConfig is a (registration-config Time (Listof Region))
(struct registration-config (deadline regions) #:transparent)

;; a RegisterEvent is a (register-evt Symbol Time)
(struct register-evt (name time) #:transparent)

;; a GetEventInfo is a (get-evt-info Symbol Chan)
(struct get-evt-info (name chan) #:transparent)

;; an EventTime is an (evt-time Symbol Time)
(struct evt-info (name time) #:transparent)

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
;; Publish-Subscribe Conversations
;; Conversations involve a Pub-Sub server, a publisher, and a subscriber.
;; Publishers publish information to the server with a Publish message. They may remove the published information with a Withdraw
;; message. Subscribers can access information from the server with a Message message, which will send to the subscriber the
;; information currently published to the server with a Payload message. Subscribers can also send a Subscribe message, which
;; will sign subscribers up to receive updates via a Payload struct whenever a publisher updates information.
;; This conversation manifests in two ways:
;; - A Candidate Registry (server) that tracks eligible candidates (publishers) for Vote Leaders and Voters (subscribers).
;; - a Participation Registry (server) that tracks voters participating in an election (publishers) for Vote Leaders (subscribers).
;;
;; Voting Conversations
;; The Vote Leader asks voters to vote with a Ballot message, containing the list of candidates still in the running. Voters reply with
;; a Vote message containing the voter's name and the candidate they'd like to vote for. If one candidate has received more than half
;; of the votes the Vote Leader has received, the Vote Leader declares that candidate the winner of the Vote Leader's region with a
;; DeclareWinner message sent to the Region manager. Otherwise, the candidate with the least votes is eliminated from the next round of voting.
;; The Region Manager elects whichever candidate has won the most regions (according to the Vote Leaders).
;;
;; Registration Conversations
;; Voters register to vote by sending a Register message to the Voter Registry, containing the name of the Voter and the region the
;; voter would like to register in. If the voter is unregistered, registration succeeds, and otherwise fails. Voters may change
;; the region they're registered in with a ChangeRegistration message, containing the voter's name and the region they'd like to
;; be registered in, which succeeds if the voter is registered and otherwise fails. Voters may also unregister with an Unregister message
;; containing their name, which succeeds if the Voter is registered but otherwise fails. These changes to the registration status
;; of voters only take effect for the upcoming election if received prior to the registration deadline.
;; After the deadline has passed, Vote Leaders request the voters registered in their region with the VoterRoll message, and the
;; Voter Registry replies with a Payload message with the requested voters.
;;
;; Key-Value Store/Event Conversations
;; Conversations involve a server, publisher and subscriber.
;; Publishers publish information with a RegisterEvent message containing a key and a value to associate with it.
;; Subscribers may receive the information stored at a key with a GetEventInfo message with the key of interest,
;; and the server responds with an EventInfo message containing the value associated with the key if the key
;; is present, and an empty value otherwise.
;; This conversation manifests in one way:
;; - The Event Registry (server) stores deadlines for events posted by the Region Manager (publisher) that affect voters (subscribers), such as the registration deadline.
;; 

