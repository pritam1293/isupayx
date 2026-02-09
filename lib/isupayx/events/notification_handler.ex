defmodule Isupayx.Events.NotificationHandler do
  @moduledoc """
  Subscribes to transaction events and sends notifications.
  
  Simulates sending notifications to:
  - Merchant webhook
  - Customer email/SMS
  - Internal monitoring system
  
  On failure, sends event to DeadLetterQueue for retry.
  """

  use GenServer
  require Logger
  alias Isupayx.Events.{Publisher, DeadLetterQueue}

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    # Subscribe to transaction events
    Phoenix.PubSub.subscribe(Isupayx.PubSub, Publisher.topic())
    Logger.info("[NotificationHandler] Subscribed to #{Publisher.topic()}")
    {:ok, %{}}
  end

  @impl true
  def handle_info({:transaction_event, event}, state) do
    Logger.info("[NotificationHandler] Received event: #{event.type} for transaction #{event.transaction_id}")
    
    case send_notification(event) do
      :ok ->
        Logger.info("[NotificationHandler] ✅ Notification sent successfully")
      {:error, reason} ->
        Logger.warning("[NotificationHandler] ❌ Notification failed: #{inspect(reason)}")
        # Send to DLQ for retry
        DeadLetterQueue.enqueue(event)
    end
    
    {:noreply, state}
  end

  # Simulates sending notification (90% success rate)
  defp send_notification(event) do
    # Simulate network call delay
    Process.sleep(10)
    
    # Simulate random failure (10% failure rate for demo)
    if :rand.uniform(100) <= 90 do
      # Success
      Logger.debug("[NotificationHandler] Sent webhook to merchant #{event.merchant_id}")
      :ok
    else
      # Failure
      {:error, :network_timeout}
    end
  end
end
