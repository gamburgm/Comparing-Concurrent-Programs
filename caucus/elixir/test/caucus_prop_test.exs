defmodule RegistryProps do
  use PropCheck

  def three(_arg) do
    3
  end

  property "stores results" do
    length = choose(1, :inf)
    candidate_structs = let {str, n, t} <- {char_list(), nat(), any()} do
      %Candidate{name: str, tax_rate: n, pid: t}
    end

    registry = AbstractRegistry.create(Candidate)

    forall cand <- candidate_structs do
      send registry, cand
      send registry, {:msg, self()}

      receive do
        %AbstractRegistry{values: v, type: Candidate} -> MapSet.size(v) == 1
        _ -> false
      end
    end
  end


  property "three" do
    forall n <- any() do
      three(n) == 3
    end
  end
end
