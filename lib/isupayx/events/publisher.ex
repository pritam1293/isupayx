defmodule Isupayx.Events.Publisher do
  @moduledoc """
  Event publisher for transaction lifecycle events.
  
  Publishes events to Phoenix.PubSub for async processing.
  Events include: transaction.created, transaction.authorized, transaction.failed
  """

  @topic "transactions"

  @doc """
  Publishes a transaction event to PubSub.
  
  ## Examples
  
      publish(:created, transaction)
      publish(:authorized, transaction)
      publish(:failed, transaction, %{reason: "insufficient_funds"})
  """
  def publish(event_type, transaction, metadata \\ %{}) do
    event = %{
      type: event_type,
      transaction_id: transaction.id,
      merchant_id: transaction.merchant_id,
      amount: transaction.amount,
      currency: transaction.currency,
      payment_method: transaction.payment_method,
      status: transaction.status,
      timestamp: DateTime.utc_now(),
      metadata: metadata
    }
    
    Phoenix.PubSub.broadcast(
      Isupayx.PubSub,
      @topic,
      {:transaction_event, event}
    )
  end

  @doc """
  Returns the PubSub topic name for transaction events.
  """
  def topic, do: @topic
end
