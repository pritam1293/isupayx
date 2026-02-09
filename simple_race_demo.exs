# Simple Race Condition Demo
# This script demonstrates race conditions WITHOUT needing the full app

IO.puts("\n=== Race Condition Demo (WITHOUT Protection) ===\n")

# Shared counter (using Agent for simplicity)
{:ok, counter} = Agent.start_link(fn -> 0 end)

# Function with race condition
increment_with_race = fn id ->
  # Read current value
  current = Agent.get(counter, & &1)
  
  # Simulate processing delay (race window)
  Process.sleep(10)
  
  # Write back incremented value
  Agent.update(counter, fn _ -> current + 1 end)
  
  IO.puts("Task #{id}: Read #{current}, Writing #{current + 1}")
  current + 1
end

IO.puts("Starting 10 concurrent tasks...\n")

# Run 10 concurrent increments
tasks = Enum.map(1..10, fn id ->
  Task.async(fn -> increment_with_race.(id) end)
end)

results = Task.await_many(tasks)
final = Agent.get(counter, & &1)

IO.puts("\n--- Results ---")
IO.puts("Expected: 10")
IO.puts("Actual: #{final}")

if final == 10 do
  IO.puts("✅ Lucky - no race condition!")
else
  IO.puts("❌ Race condition! Lost #{10 - final} updates")
end

IO.puts("Task results: #{inspect(results)}")
IO.puts("(Notice duplicates - multiple tasks read same value)\n")
