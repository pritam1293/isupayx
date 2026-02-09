defmodule Isupayx.Events.DeadLetterQueue do
  @moduledoc """
  Dead Letter Queue for failed event notifications with exponential backoff.
  
  Retry strategy:
  - Attempt 1: Immediate
  - Attempt 2: 1 second delay
  - Attempt 3: 5 seconds delay
  - Attempt 4: 30 seconds delay
  - After 4 attempts: Mark as permanently failed
  """

  use GenServer
  require Logger

  @max_retries 4
  @retry_delays [0, 1_000, 5_000, 30_000]  # milliseconds

  defmodule Entry do
    @moduledoc false
    defstruct [:event, :attempt, :enqueued_at, :last_attempt_at]
  end

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Enqueues a failed event for retry.
  """
  def enqueue(event) do
    GenServer.cast(__MODULE__, {:enqueue, event})
  end

  @impl true
  def init(_opts) do
    Logger.info("[DeadLetterQueue] Started with exponential backoff: #{inspect(@retry_delays)} ms")
    {:ok, %{queue: [], stats: %{enqueued: 0, retried: 0, succeeded: 0, failed: 0}}}
  end

  @impl true
  def handle_cast({:enqueue, event}, state) do
    entry = %Entry{
      event: event,
      attempt: 1,
      enqueued_at: DateTime.utc_now(),
      last_attempt_at: nil
    }
    
    new_stats = Map.update(state.stats, :enqueued, 1, &(&1 + 1))
    Logger.warning("[DLQ] Enqueued event #{event.transaction_id} (attempt 1/#{@max_retries})")
    
    # Schedule immediate retry
    schedule_retry(entry, 0)
    
    {:noreply, %{state | queue: [entry | state.queue], stats: new_stats}}
  end

  @impl true
  def handle_info({:retry, entry}, state) do
    Logger.info("[DLQ] Retrying event #{entry.event.transaction_id} (attempt #{entry.attempt}/#{@max_retries})")
    
    new_stats = Map.update(state.stats, :retried, 1, &(&1 + 1))
    
    case retry_notification(entry.event) do
      :ok ->
        # Success - remove from queue
        Logger.info("[DLQ] ✅ Retry succeeded for #{entry.event.transaction_id}")
        new_stats = Map.update(new_stats, :succeeded, 1, &(&1 + 1))
        new_queue = Enum.reject(state.queue, fn e -> e.event.transaction_id == entry.event.transaction_id end)
        {:noreply, %{state | queue: new_queue, stats: new_stats}}
      
      {:error, reason} ->
        if entry.attempt >= @max_retries do
          # Max retries reached - mark as permanently failed
          Logger.error("[DLQ] ❌ Max retries reached for #{entry.event.transaction_id}. Marking as failed.")
          new_stats = Map.update(new_stats, :failed, 1, &(&1 + 1))
          new_queue = Enum.reject(state.queue, fn e -> e.event.transaction_id == entry.event.transaction_id end)
          {:noreply, %{state | queue: new_queue, stats: new_stats}}
        else
          # Schedule next retry with exponential backoff
          updated_entry = %{entry | 
            attempt: entry.attempt + 1,
            last_attempt_at: DateTime.utc_now()
          }
          
          delay = Enum.at(@retry_delays, entry.attempt)
          Logger.warning("[DLQ] Retry failed: #{inspect(reason)}. Scheduling attempt #{updated_entry.attempt}/#{@max_retries} in #{delay}ms")
          
          schedule_retry(updated_entry, delay)
          
          new_queue = Enum.map(state.queue, fn e ->
            if e.event.transaction_id == entry.event.transaction_id, do: updated_entry, else: e
          end)
          
          {:noreply, %{state | queue: new_queue, stats: new_stats}}
        end
    end
  end

  @impl true
  def handle_info(:print_stats, state) do
    Logger.info("[DLQ] Stats: #{inspect(state.stats)} | Queue size: #{length(state.queue)}")
    # Schedule next stats print
    Process.send_after(self(), :print_stats, 60_000)
    {:noreply, state}
  end

  defp schedule_retry(entry, delay) do
    Process.send_after(self(), {:retry, entry}, delay)
  end

  defp retry_notification(event) do
    # Simulate retry attempt (70% success rate)
    Process.sleep(10)
    
    if :rand.uniform(100) <= 70 do
      :ok
    else
      {:error, :network_timeout}
    end
  end
end
