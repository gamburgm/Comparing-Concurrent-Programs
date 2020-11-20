# a RoundInfo is a {:round_info, [List-of Name], [List-of Name], [Hash-of Name Number], (U RoundLoser RoundWinner)}
# a RoundLoser is a {:round_loser, Name}
# a RoundWinner is a {:round_winner, Name}

defmodule GenerateJSON do
  # [Hash-of Region [List-of Round-Info]] [Hash-of Region Name] Name String -> void
  def record_results(round_results, region_winners, winner, filename) do
    test_output = %{
      "winner" => winner,
      "regions" => Enum.map(round_results, fn {region, results} ->
        generate_region_results(region, results, region_winners[region])
      end)
    }

    File.write(filename, Poison.encode(test_output))
  end

  def generate_region_results(region_name, round_results, region_winner) do
    %{
      "name" => region_name,
      "winner" => region_winner,
      "rounds" => Enum.map(round_results, self.generate_round_result)
    }
  end

  def generate_round_result(%{:round_info, voters, cands, tally, outcome}) do
    %{
      "active_voters" => voters,
      "active_cands" => cands,
      "tally" => tally,
      "result" => generate_outcome(outcome)
    }
  end

  def generate_outcome({:round_loser, name}), do: %{"type" => "Loser", "candidate" => name}

  def generate_outcome({:round_winner, name}), do: %{"type" => "Winner", "candidate" => name}
end
