ExUnit.start()
Code.require_file("caucus.exs", "./")

# CANDIDATE
# 1. check that spawn sends a message to the candidate registry
# 2. check that a bad ballot causes failure
# 3. check that a good ballot proceeds (somehow)
defmodule CandidateTest do
  use ExUnit.Case
  import Candidate

  # check that spawn sends a message to the candidate registry
  test "Registers with the candidate registry" do
    cand_pid = Candidate.spawn("A", 5, 5, self())
    assert_receive %Candidate{name: "A", tax_rate: 5, pid: cand_pid}
  end
end

