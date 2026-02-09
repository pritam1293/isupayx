defmodule Isupayx.Concurrency.DistributedMutex do
  @moduledoc """
  Simple distributed mutex implementation using ETS.
  
  Prevents race conditions when multiple processes try to access the same resource.
  Uses TTL (Time To Live) to automatically release locks after timeout.
  
  ## Usage
  
      lock_key = "transaction:\#{merchant_id}:\#{ref_id}"
      case DistributedMutex.acquire(lock_key, 5000) do
        {:ok, lock_id} ->
          # Critical section - do work
          result = process_transaction()
          DistributedMutex.release(lock_key, lock_id)
          {:ok, result}
        {:error, :locked} ->
          {:error, :resource_locked}
      end
  """

  use GenServer
  require Logger

  @table_name :distributed_locks
  @cleanup_interval 1_000  # Cleanup expired locks every 1 second

  defmodule Lock do
    @moduledoc false
    defstruct [:key, :lock_id, :owner_pid, :acquired_at, :ttl]
  end

  ## Client API

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Attempts to acquire a lock for the given key.
  
  Returns `{:ok, lock_id}` if lock acquired, `{:error, :locked}` if already locked.
  
  ## Parameters
  - key: Unique identifier for the resource (e.g., "transaction:merchant_id:ref_id")
  - ttl: Time to live in milliseconds (default: 5000ms)
  """
  def acquire(key, ttl \\ 5000) do
    GenServer.call(__MODULE__, {:acquire, key, ttl})
  end

  @doc """
  Releases a lock.
  
  Returns `:ok` if released, `{:error, :not_owner}` if lock_id doesn't match.
  """
  def release(key, lock_id) do
    GenServer.call(__MODULE__, {:release, key, lock_id})
  end

  @doc """
  Checks if a key is currently locked.
  """
  def locked?(key) do
    case :ets.lookup(@table_name, key) do
      [{^key, lock}] -> 
        # Check if lock is expired
        now = System.monotonic_time(:millisecond)
        expires_at = lock.acquired_at + lock.ttl
        expires_at > now
      [] -> 
        false
    end
  end

  @doc """
  Executes a function with a lock held.
  
  Automatically releases the lock after execution.
  """
  def with_lock(key, ttl \\ 5000, fun) do
    case acquire(key, ttl) do
      {:ok, lock_id} ->
        try do
          result = fun.()
          {:ok, result}
        after
          release(key, lock_id)
        end
      {:error, :locked} = error ->
        error
    end
  end

  ## Server Callbacks

  @impl true
  def init(_opts) do
    # Create ETS table for locks
    :ets.new(@table_name, [:named_table, :public, :set])
    
    # Schedule periodic cleanup of expired locks
    schedule_cleanup()
    
    Logger.info("[DistributedMutex] Started with TTL cleanup every #{@cleanup_interval}ms")
    {:ok, %{}}
  end

  @impl true
  def handle_call({:acquire, key, ttl}, {owner_pid, _}, state) do
    now = System.monotonic_time(:millisecond)
    
    case :ets.lookup(@table_name, key) do
      [] ->
        # No existing lock - acquire it
        lock_id = generate_lock_id()
        lock = %Lock{
          key: key,
          lock_id: lock_id,
          owner_pid: owner_pid,
          acquired_at: now,
          ttl: ttl
        }
        
        :ets.insert(@table_name, {key, lock})
        Logger.debug("[Mutex] Lock acquired: #{key} (#{lock_id})")
        {:reply, {:ok, lock_id}, state}
      
      [{^key, existing_lock}] ->
        # Check if existing lock is expired
        expires_at = existing_lock.acquired_at + existing_lock.ttl
        
        if expires_at <= now do
          # Lock expired - replace it
          lock_id = generate_lock_id()
          lock = %Lock{
            key: key,
            lock_id: lock_id,
            owner_pid: owner_pid,
            acquired_at: now,
            ttl: ttl
          }
          
          :ets.insert(@table_name, {key, lock})
          Logger.debug("[Mutex] Lock acquired (expired lock replaced): #{key} (#{lock_id})")
          {:reply, {:ok, lock_id}, state}
        else
          # Lock still valid
          Logger.debug("[Mutex] Lock denied - already locked: #{key}")
          {:reply, {:error, :locked}, state}
        end
    end
  end

  @impl true
  def handle_call({:release, key, lock_id}, _from, state) do
    case :ets.lookup(@table_name, key) do
      [{^key, lock}] ->
        if lock.lock_id == lock_id do
          :ets.delete(@table_name, key)
          Logger.debug("[Mutex] Lock released: #{key} (#{lock_id})")
          {:reply, :ok, state}
        else
          Logger.warning("[Mutex] Release denied - lock_id mismatch: #{key}")
          {:reply, {:error, :not_owner}, state}
        end
      
      [] ->
        Logger.warning("[Mutex] Release denied - no lock found: #{key}")
        {:reply, {:error, :not_found}, state}
    end
  end

  @impl true
  def handle_info(:cleanup_expired_locks, state) do
    now = System.monotonic_time(:millisecond)
    
    # Find and remove expired locks
    expired_count = :ets.foldl(fn {key, lock}, acc ->
      expires_at = lock.acquired_at + lock.ttl
      if expires_at <= now do
        :ets.delete(@table_name, key)
        acc + 1
      else
        acc
      end
    end, 0, @table_name)
    
    if expired_count > 0 do
      Logger.debug("[Mutex] Cleaned up #{expired_count} expired lock(s)")
    end
    
    schedule_cleanup()
    {:noreply, state}
  end

  ## Private Functions

  defp generate_lock_id do
    :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)
  end

  defp schedule_cleanup do
    Process.send_after(self(), :cleanup_expired_locks, @cleanup_interval)
  end
end
