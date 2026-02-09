# Demo: Race Condition Prevention WITH Mutex
# Run with: mix run demo_with_mutex.exs

alias Isupayx.Concurrency.DistributedMutex

IO.puts("\n=== Mutex Demo (WITH Mutex Protection) ===\n")

# Shared resource: Counter file
counter_file = "mutex_counter.txt"
File.write!(counter_file, "0")

# Function that simulates processing WITH mutex
process_with_mutex = fn id ->
  lock_key = "counter_lock"
  
  case DistributedMutex.acquire(lock_key, 2000) do
    {:ok, lock_id} ->
      try do
        # Read counter
        current = File.read!(counter_file) |> String.trim() |> String.to_integer()
        
        # Simulate processing delay
        Process.sleep(50)
        
        # Increment and write back
        new_value = current + 1
        File.write!(counter_file, Integer.to_string(new_value))
        
        IO.puts("Task #{id}: Read #{current}, Writing #{new_value} [LOCKED]")
        new_value
      after
        # Always release lock
        DistributedMutex.release(lock_key, lock_id)
      end
    
    {:error, :locked} ->
      IO.puts("Task #{id}: ⏳ Waiting for lock...")
      Process.sleep(100)
      process_with_mutex.(id)  # Retry
  end
end

# Using with_lock helper (cleaner API)
process_with_lock_helper = fn id ->
  lock_key = "counter_lock"
  
  case DistributedMutex.with_lock(lock_key, 2000, fn ->
    # Read counter
    current = File.read!(counter_file) |> String.trim() |> String.to_integer()
    
    # Simulate processing delay
    Process.sleep(50)
    
    # Increment and write back
    new_value = current + 1
    File.write!(counter_file, Integer.to_string(new_value))
    
    IO.puts("Task #{id}: Read #{current}, Writing #{new_value} [PROTECTED]")
    new_value
  end) do
    {:ok, result} -> result
    {:error, :locked} ->
      IO.puts("Task #{id}: ⏳ Waiting for lock...")
      Process.sleep(100)
      process_with_lock_helper.(id)  # Retry
  end
end

# Spawn 10 concurrent tasks
IO.puts("Starting 10 concurrent tasks WITH mutex protection...\n")

tasks = Enum.map(1..10, fn id ->
  Task.async(fn -> process_with_lock_helper.(id) end)
end)

# Wait for all tasks
results = Task.await_many(tasks, 30_000)

# Check final value
final_value = File.read!(counter_file) |> String.trim() |> String.to_integer()

IO.puts("\n--- Results ---")
IO.puts("Expected final value: 10")
IO.puts("Actual final value: #{final_value}")

if final_value == 10 do
  IO.puts("✅ Mutex successfully prevented race condition!")
else
  IO.puts("❌ Unexpected: #{10 - final_value} updates lost")
end

IO.puts("\nReturned values from tasks: #{inspect(results)}")
IO.puts("(Notice sequential values - mutex ensures no conflicts)")

# Cleanup
File.rm!(counter_file)

IO.puts("\n=== Demo Complete ===\n")
