defmodule Isupayx.Repo.Migrations.CreatePaymentMethods do
  use Ecto.Migration

  def change do
    create table(:payment_methods, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :code, :string, null: false
      add :name, :string, null: false
      add :description, :text
      
      add :min_amount, :decimal, precision: 15, scale: 2
      add :max_amount, :decimal, precision: 15, scale: 2
      add :per_transaction_limit, :decimal, precision: 15, scale: 2
      
      add :daily_limit, :decimal, precision: 15, scale: 2
      add :daily_transaction_count_limit, :integer
      
      add :is_active, :boolean, default: true, null: false
      add :requires_verification, :boolean, default: false, null: false
      
      add :processing_fee_percentage, :decimal, precision: 5, scale: 2, default: 0
      add :processing_fee_fixed, :decimal, precision: 15, scale: 2, default: 0
      
      add :config, :map

      timestamps(type: :utc_datetime)
    end

    create unique_index(:payment_methods, [:code])
    create index(:payment_methods, [:is_active])
  end
end
