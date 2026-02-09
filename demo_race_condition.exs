# Demo: Race Condition WITHOUT Mutex
# Run with: mix run demo_race_condition.exs

alias Isupayx.Repo
alias Isupayx.Transactions.Transaction
alias Isupayx.Merchants.Merchant

IO.puts("\n=== Race Condition Demo (WITHOUT Mutex) ===\n")

# Get test merchant
merchant = Repo.get_by!(Merchant, api_key: "test_key_merchant_001")

# Shared resource: Counter file
counter_file = "race_counter.txt"
File.write!(counter_file, "0")

# Function that simulates processing with race condition
process_without_mutex = fn id ->
  # Read counter
  current = File.read!(counter_file) |> String.trim() |> String.to_integer()
  
  # Simulate processing delay (race condition window)
  Process.sleep(50)
  
  # Increment and write back
  new_value = current + 1
  File.write!(counter_file, Integer.to_string(new_value))
  
  IO.puts("Task #{id}: Read #{current}, Writing #{new_value}")
  new_value
end

# Spawn 10 concurrent tasks
IO.puts("Starting 10 concurrent tasks WITHOUT mutex...\n")

tasks = Enum.map(1..10, fn id ->
  Task.async(fn -> process_without_mutex.(id) end)
end)

# Wait for all tasks
results = Task.await_many(tasks)

# Check final value
final_value = File.read!(counter_file) |> String.trim() |> String.to_integer()

IO.puts("\n--- Results ---")
IO.puts("Expected final value: 10")
IO.puts("Actual final value: #{final_value}")

if final_value == 10 do
  IO.puts("✅ No race condition occurred (lucky!)")
else
  IO.puts("❌ Race condition detected! Lost updates: #{10 - final_value}")
end

IO.puts("\nReturned values from tasks: #{inspect(results)}")
IO.puts("(Notice duplicate values - multiple tasks read same counter)")

# Cleanup
File.rm!(counter_file)

IO.puts("\n=== Demo Complete ===\n")
