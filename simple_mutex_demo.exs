# Simple Mutex Demo
# Demonstrates how locks prevent race conditions

IO.puts("\n=== Mutex Demo (WITH Protection) ===\n")

# Simple lock using ETS
:ets.new(:simple_lock, [:named_table, :public, :set])
{:ok, counter} = Agent.start_link(fn -> 0 end)

defmodule SimpleLock do
  # Acquire lock
  def acquire do
    case :ets.insert_new(:simple_lock, {:lock, self()}) do
      true -> :ok
      false -> 
        Process.sleep(5)
        acquire()
    end
  end

  # Release lock  
  def release do
    :ets.delete(:simple_lock, :lock)
  end
end

# Function WITH mutex protection
increment_with_mutex = fn id ->
  SimpleLock.acquire()
  
  try do
    # Read current value
    current = Agent.get(counter, & &1)
    
    # Simulate processing delay
    Process.sleep(10)
    
    # Write back incremented value
    Agent.update(counter, fn _ -> current + 1 end)
    
    IO.puts("Task #{id}: Read #{current}, Writing #{current + 1} [LOCKED]")
    current + 1
  after
    SimpleLock.release()
  end
end

IO.puts("Starting 10 concurrent tasks WITH mutex...\n")

# Run 10 concurrent increments
tasks = Enum.map(1..10, fn id ->
  Task.async(fn -> increment_with_mutex.(id) end)
end)

results = Task.await_many(tasks, 10_000)
final = Agent.get(counter, & &1)

IO.puts("\n--- Results ---")
IO.puts("Expected: 10")
IO.puts("Actual: #{final}")

if final == 10 do
  IO.puts("✅ Mutex prevented race condition!")
else
  IO.puts("❌ Unexpected: #{10 - final} updates lost")
end

IO.puts("Task results: #{inspect(results)}")
IO.puts("(Notice sequential values - no conflicts)\n")
