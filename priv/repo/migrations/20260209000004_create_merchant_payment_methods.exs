defmodule Isupayx.Repo.Migrations.CreateMerchantPaymentMethods do
  use Ecto.Migration

  def change do
    create table(:merchant_payment_methods, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :merchant_id, references(:merchants, type: :binary_id, on_delete: :delete_all), null: false
      add :payment_method_id, references(:payment_methods, type: :binary_id, on_delete: :delete_all), null: false
      
      add :is_enabled, :boolean, default: true, null: false
      
      add :custom_min_amount, :decimal, precision: 15, scale: 2
      add :custom_max_amount, :decimal, precision: 15, scale: 2
      add :custom_daily_limit, :decimal, precision: 15, scale: 2
      
      add :custom_fee_percentage, :decimal, precision: 5, scale: 2
      add :custom_fee_fixed, :decimal, precision: 15, scale: 2
      
      add :settlement_days, :integer, default: 1
      add :auto_settlement, :boolean, default: true
      
      add :requires_manual_review, :boolean, default: false
      add :max_transaction_count_per_day, :integer
      
      add :config, :map
      
      add :enabled_at, :utc_datetime
      add :disabled_at, :utc_datetime
      add :enabled_by, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:merchant_payment_methods, [:merchant_id, :payment_method_id],
                        name: :merchant_payment_methods_merchant_id_payment_method_id_index)
    create index(:merchant_payment_methods, [:merchant_id])
    create index(:merchant_payment_methods, [:payment_method_id])
    create index(:merchant_payment_methods, [:is_enabled])
  end
end
