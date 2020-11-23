defmodule CandidateState do
  use ExUnit.Case
  use PropCheck
  use PropCheck.StateM

  defmodule CandidateInterface do
    def ballot(pid, ballot) do
      send pid, {:ballot, ballot}
    end
  end

  def initial_state do
    let {name, threshold} <- {char_list(), nat()} do
      %{pid: Candidate.spawn(name, any(), threshold, self()), name: name, threshold: threshold}
    end
  end

  def command(%{pid: pid, name: name, threshold: num}) do
    let votes <- range(num + 1, :inf) do
      {:call, CandidateInterface, :ballot, [pid, %{name => votes}]}
    end
  end

  def precondition(_, {:call, _, _, [_, map]}) do
    [h | _] = Map.values(map)
    Kernel.map_size(map) == 1 && h > 0
  end

  def postcondition(_, _, _), do: true

  def next_state(s, _, _), do: s

  property "Will not withdraw from race if gets enough votes" do
    trap_exit(forall cmds <- commands(__MODULE__) do
      {_, state, res} = run_commands(__MODULE__, cmds)
      res == :ok
    end)
  end
end

defmodule RegistryState do
  use ExUnit.Case
  use PropCheck
  use PropCheck.StateM

  def oneof_struct(s), do: elements(MapSet.to_list(s.data))

  defmodule RegistryInterface do
    def send_value(pid, val) do
      send pid, val
    end

    def remove_value(pid, val) do
      send pid, {:remove, val}
    end
  end

  def initial_state do
    pid = AbstractRegistry.create(CandStruct)
    %{pid: pid, type: Voter, data: MapSet.new, subscribers: MapSet.new}
  end

  def command(%{pid: pid}) do
    let {name, tr, cand_pid} <- {char_list(), nat(), nat()} do
      frequency([{3, {:call, RegistryInterface, :send_value, [pid, %CandStruct{name: name, tax_rate: tr, pid: cand_pid}]}},
                 {1, {:call, RegistryInterface, :remove_value, [pid, %CandStruct{name: name, tax_rate: tr, pid: cand_pid}]}}])
    end
  end

  def next_state(s, _, {:call, _, :send_value, [_, struct]}) do
    Map.put(s, :data, MapSet.put(s.data, struct))
  end

  def next_state(s, _, {:call, _, :remove_value, [_, struct]}) do
    Map.put(s, :data, MapSet.delete(s.data, struct))
  end

  def precondition(s, {:call, _, :remove_value, [_, struct]}) do
    MapSet.member?(s.data, struct)
  end

  def precondition(_, _), do: true

  def postcondition(%{data: data}, {:call, _, :send_value, [_, struct]}, _) do
    IO.puts inspect(struct)
    IO.puts inspect(data)
    MapSet.member?(data, struct)
  end

  def postcondition(%{pid: pid}, _, _) do
    Process.alive?(pid)
  end

  property "Will work" do
    forall cmds <- commands(__MODULE__) do
      {_, _, res} = run_commands(__MODULE__, cmds)
      res == :ok
    end
  end
end

