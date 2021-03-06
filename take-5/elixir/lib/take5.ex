####### Protocol #######
#
# a PlayerID is a Symbol
# a Hand is a [List-of Card]
# a Score is a Nat
# a Scores is a [Hash-of PlayerID Score]
# a RoundNo is a Nat
#
# a Round is a {:round, RoundNo, [List-of Card], [List-of Row], PID}
# a PlayerInfo is a {:player, PlayerID, PID}
# a DeclaredWinners is a {:declared_winners, [List-of PlayerID]}
#
# There are two roles in the protocol:
# 1. The Dealer, who manages a run of the game. There is one dealer per game instance.
# 2. The Player, who attempts to win the game by communicating with the Dealer. There
#    are between 2 and 10 players per game.
# 3. The Game Observer, who monitors and listens for the results of the game. There is
#    one Game Observer per game instance.
#
# Conversations:
# There is a conversation about playing one round of the game. The Dealer sends each
# participating player a Round message, containing the round number, the cards in that
# Player's hand, the current rows of the game, and the Dealer's PID. Player's respond 
# by sending a Move message to the Dealer's PID, containing the round number of the
# Round message, the PlayerID of the Player, and the card that the Player has selected
# to play for the round.
#
# The Dealer manages 10 rounds in this way.
# 
# There is a conversation about the results of the game. When the game ends, the Dealer
# sends a DeclaredWinners message to the PID of the Game Observer, containing the PlayerIDs
# of the Players with the lowest scores in the game.

# the Dealer that administers and manages the game for Players

defmodule RoundHandler do
  use GenServer

  # Client API

  def start_link(round_no, players) do
    GenServer.start_link(__MODULE__, [round_no, players], [])
  end

  # Server API

  def init([round_no, players]) do
    start_timeout()
    {:ok, %{round_no: round_no, players: players, moves: []}}
  end

  def handle_info(
    m = {:move, round_no, _player, _c},
    state = %{round_no: round_no, players: players, moves: moves}
  ) do
    Logging.log_move(m)
    new_moves = [m | moves]
    if length(new_moves) == length(players) do
      conclude_round(state)
    else
      {:noreply, %{round_no: round_no, players: players, moves: new_moves}}
    end
  end

  def handle_info(:timeout, state) do
    conclude_round(state)
  end

  defp start_timeout do
    Process.send_after self(), :timeout, 1000
  end

  defp conclude_round(s = %{round_no: n, players: _p, moves: m}) do
    Dealer.end_round(Take5.Dealer, n, m)
    {:stop, :normal, s}
  end
end

defmodule GameState do
  defstruct [:hands, :rows, :scores]
end

defmodule Dealer do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, :ok, opts)
  end
  
  def init(:ok) do
    open_registration()
    {:ok, %{reg_closed: false, players: [], curr_round: 0, game_state: %{}}}
  end

  def register(server, player) do
    GenServer.call(server, {:register, player})
  end

  def end_round(server, round_no, moves) do
    GenServer.cast(server, {:end_round, round_no, moves})
  end

  # Server API

  def handle_call({:register, p}, s = %{reg_closed: r, players: players, curr_round: round_no, game_state: g}) do
    if r do
      {:reply, {:error, :closed}, s}
    else
      {:reply, :ok, %{reg_closed: r, players: [p | players], curr_round: round_no, game_state: g}}
    end
  end

  def handle_cast(
    {:end_round, round_no, moves},
    %{round_no: round_no, reg_closed: true, players: players, game_state: game_state}
  ) do
    {players_that_moved, new_gs = %GameState{hands: _, rows: _, scores: new_scores}} = calculate_results(players, moves, game_state)

    if round_no == 10 do
      winner_s = Rules.lowest_scores(new_scores)
      Logging.log_winners(winner_s)
      IO.puts "Winners! #{inspect winner_s}"
      {:stop, :normal}
    else
      new_round_no = round_no + 1
      start_round(new_round_no, players_that_moved, new_gs)
      {:noreply, %{round_no: new_round_no, players: players_that_moved, reg_closed: true, game_state: new_gs}}
    end
  end


  def handle_info(:start_game, %{players: players}) do
    game_state = initialize_game(players)
    start_round(1, players, game_state)
    {:noreply, %{players: players, reg_closed: true, curr_round: 1, game_state: game_state}}
  end

  # For junk messages
  def handle_info(_msg, state) do
    {:noreply, state}
  end

  ## Helper Functions

  defp open_registration do
    Process.send_after self(), :start_game, 1_000_000
  end

  defp initialize_game(players) do
    starting_deck = Deck.create_deck()
    player_names = Enum.map(players, fn {:player, name, _} -> name end)

    {:ok, starting_hands, new_deck} = Deck.deal(starting_deck, player_names)

    {starting_rows, _} = Enum.reduce(1..4, {[], new_deck}, fn _, {curr_rows, curr_deck} ->
      {:ok, drawn_card, new_deck} = Deck.draw_one(curr_deck)
      {[{:row, [drawn_card]} | curr_rows], new_deck}
    end)

    %GameState{hands: starting_hands, rows: starting_rows, scores: Map.new(player_names, fn n -> {n, 0} end)}
  end

  defp start_round(round_no, players, %GameState{hands: h, rows: rows, scores: _}) do
    {:ok, round_pid} = RoundHandler.start_link(round_no, players)

    Enum.each(players, fn {:player, name, pid} ->
      player_hand = Map.get(h, name)
      send pid, {:round, round_no, player_hand, rows, round_pid}
    end)
  end

  defp filter_keys(hash, keys) do
    Enum.reduce(hash, %{}, fn {key, val}, new_hash ->
      if MapSet.member?(keys, key) do
        Map.put(new_hash, key, val)
      else
        new_hash
      end
    end)
  end

  defp calculate_results(players, moves, %GameState{hands: hands, rows: rows, scores: scores}) do
    moved_player_names = MapSet.new(Enum.map(moves, fn {:move, _no, name, _c} -> name end))
    players_that_moved = Enum.filter(players, fn {:player, name, _} -> MapSet.member?(moved_player_names, name) end)

    filtered_scores = filter_keys(scores, moved_player_names)

    {new_rows, new_scores} = Rules.play_round(rows, moves, filtered_scores)

    Logging.log_rows(new_rows)
    Logging.log_scores(new_scores)

    new_hands = Enum.reduce(moves, %{}, fn {:move, _no, name, c}, new_hands ->
      Map.put(new_hands, name, List.delete(Map.get(hands, name), c))
    end)

    {players_that_moved, %GameState{hands: new_hands, rows: new_rows, scores: new_scores}}
  end
end

defmodule Player do
  def create(client) do
    spawn fn ->
      name = register_player(client)
      loop(name, client)
    end
  end

  defp register_player(client) do
    IO.puts inspect(client)
    IO.puts "about to receive"
    {:ok, msg} = :gen_tcp.recv(client, 0)
    IO.puts "Received"
    IO.puts msg
    case Translator.parse(Poison.decode!(msg)) do
      {:player, name} ->
        player = {:player, name, self()}
        Dealer.register(Take5.Dealer, player)
        name
    end
  end

  defp loop(name, client) do
    receive do
      {:round, round_no, cards, rows, pid} ->
        move_request = {:move_request, round_no, cards, rows}
        :gen_tcp.send(client, Poison.encode!(Translator.unparse(move_request)))

        {:ok, msg} = :gen_tcp.recv(client, 0)
        case Translator.parse(Poison.decode!(msg)) do
          m = {:move, ^round_no, ^name, _c} ->
            send pid, m
            loop(name, client)
        end
    end

  end
end

defmodule PlayerServer do
  def create(port) do
    {:ok, socket} = :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])
    loop(socket)
  end

  defp loop(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    {:ok, pid} = Task.Supervisor.start_child(Player.TaskSupervisor, fn -> Player.create(client) end)
    :ok = :gen_tcp.controlling_process(client, pid)
    loop(socket)
  end
end

defmodule Take5 do
  use Application

  def start(_type, _args) do
    children = [
      {Dealer, name: Take5.Dealer},
      {Task.Supervisor, name: Player.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> PlayerServer.create(8900) end}, restart: :permanent)
    ]

    opts = [strategy: :one_for_one, name: Take5.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
