defmodule Isupayx.Transactions.Transaction do
  @moduledoc """
  Transaction schema representing payment processing records.
  
  ## State Machine
  The transaction lifecycle follows this state machine:
  
  pending → processing → authorized → captured
                      → failed
                      → cancelled (before processing)
  authorized → refunded
  
  ## Business Rules
  - Transactions are created in "processing" state (TC1)
  - State transitions are validated to prevent invalid flows
  - Amount must be positive (TC3)
  - Currency must be valid ISO code
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  # Transaction states
  @states ~w(pending processing authorized captured failed cancelled refunded)
  
  # Payment methods
  @payment_methods ~w(upi credit_card debit_card netbanking)
  
  # Currencies
  @currencies ~w(INR USD EUR)

  schema "transactions" do
    # Core transaction data
    field :amount, :decimal
    field :currency, :string, default: "INR"
    field :payment_method, :string
    field :reference_id, :string
    field :status, :string, default: "processing"
    
    # Customer information (embedded for simplicity)
    field :customer_email, :string
    field :customer_phone, :string
    
    # Idempotency support
    field :idempotency_key, :string
    
    # Compliance flags (array of strings)
    # Example: ["AMOUNT_REPORTING"] for transactions > ₹200,000 (TC8)
    field :compliance_flags, {:array, :string}, default: []
    
    # Metadata for additional context (stored as JSON)
    field :metadata, :map, default: %{}
    
    # Payment gateway response
    field :gateway_transaction_id, :string
    field :gateway_response, :map
    
    # Error tracking
    field :error_code, :string
    field :error_message, :string
    
    # State transition tracking
    field :previous_status, :string
    field :status_changed_at, :utc_datetime
    
    # Timestamps
    timestamps(type: :utc_datetime)
    
    # Associations
    belongs_to :merchant, Isupayx.Merchants.Merchant
  end

  @doc """
  Changeset for transaction creation.
  """
  def changeset(transaction, attrs) do
    transaction
    |> cast(attrs, [
      :amount,
      :currency,
      :payment_method,
      :reference_id,
      :customer_email,
      :customer_phone,
      :idempotency_key,
      :merchant_id,
      :status,
      :compliance_flags,
      :metadata
    ])
    |> validate_required([
      :amount,
      :currency,
      :payment_method,
      :reference_id,
      :customer_email,
      :customer_phone,
      :merchant_id
    ])
    |> validate_number(:amount, greater_than: 0, message: "must be greater than 0")
    |> validate_inclusion(:currency, @currencies)
    |> validate_inclusion(:payment_method, @payment_methods)
    |> validate_inclusion(:status, @states)
    |> validate_format(:customer_email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, 
         message: "must be a valid email")
    |> validate_format(:customer_phone, ~r/^\+[1-9]\d{1,14}$/, 
         message: "must be a valid phone number with country code")
    |> unique_constraint(:idempotency_key, name: :transactions_merchant_id_idempotency_key_index)
    |> foreign_key_constraint(:merchant_id)
  end

  @doc """
  Changeset for state transitions.
  Validates that the transition is allowed by the state machine.
  """
  def transition_changeset(transaction, new_status, attrs \\ %{}) do
    if valid_transition?(transaction.status, new_status) do
      transaction
      |> cast(attrs, [:status, :error_code, :error_message, :gateway_transaction_id, :gateway_response])
      |> put_change(:previous_status, transaction.status)
      |> put_change(:status, new_status)
      |> put_change(:status_changed_at, DateTime.utc_now())
    else
      transaction
      |> cast(%{}, [])
      |> add_error(:status, "invalid transition from #{transaction.status} to #{new_status}")
    end
  end

  @doc """
  Validates if a state transition is allowed.
  
  ## Valid Transitions
  - pending → processing, cancelled
  - processing → authorized, failed
  - authorized → captured, refunded
  - All terminal states (failed, cancelled, captured, refunded) cannot transition
  """
  def valid_transition?(current_status, new_status) do
    case {current_status, new_status} do
      {"pending", "processing"} -> true
      {"pending", "cancelled"} -> true
      {"processing", "authorized"} -> true
      {"processing", "failed"} -> true
      {"authorized", "captured"} -> true
      {"authorized", "refunded"} -> true
      _ -> false
    end
  end

  @doc """
  Returns all valid transaction states.
  """
  def states, do: @states

  @doc """
  Returns all valid payment methods.
  """
  def payment_methods, do: @payment_methods

  @doc """
  Returns all valid currencies.
  """
  def currencies, do: @currencies

  @doc """
  Checks if transaction is in a terminal state.
  """
  def terminal_state?(status) when status in ["captured", "failed", "cancelled", "refunded"], do: true
  def terminal_state?(_), do: false

  @doc """
  Checks if transaction is successful.
  """
  def successful?(%__MODULE__{status: status}) when status in ["authorized", "captured"], do: true
  def successful?(_), do: false
end
