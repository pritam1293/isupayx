defmodule Isupayx.Repo.Migrations.CreateTransactions do
  use Ecto.Migration

  def change do
    create table(:transactions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :merchant_id, references(:merchants, type: :binary_id, on_delete: :restrict), null: false
      
      add :amount, :decimal, precision: 15, scale: 2, null: false
      add :currency, :string, default: "INR", null: false
      add :payment_method, :string, null: false
      add :reference_id, :string, null: false
      add :status, :string, default: "processing", null: false
      
      add :customer_email, :string, null: false
      add :customer_phone, :string, null: false
      
      add :idempotency_key, :string
      add :compliance_flags, {:array, :string}, default: []
      add :metadata, :map
      
      add :gateway_transaction_id, :string
      add :gateway_response, :map
      
      add :error_code, :string
      add :error_message, :text
      
      add :previous_status, :string
      add :status_changed_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:transactions, [:merchant_id])
    create index(:transactions, [:status])
    create index(:transactions, [:payment_method])
    create index(:transactions, [:reference_id])
    create index(:transactions, [:inserted_at])
    
    # Composite unique index for idempotency: same merchant + same key = unique
    create unique_index(:transactions, [:merchant_id, :idempotency_key], 
                        name: :transactions_merchant_id_idempotency_key_index)
  end
end
