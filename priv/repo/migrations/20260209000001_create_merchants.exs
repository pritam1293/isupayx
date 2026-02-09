defmodule Isupayx.Repo.Migrations.CreateMerchants do
  use Ecto.Migration

  def change do
    create table(:merchants, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :business_name, :string, null: false
      add :email, :string, null: false
      add :api_key, :string, null: false
      add :webhook_url, :string
      
      add :onboarding_status, :string, default: "pending", null: false
      add :kyc_status, :string, default: "not_started", null: false
      add :kyc_tier, :string, default: "basic", null: false
      
      add :phone, :string
      add :contact_person, :string
      add :business_type, :string
      add :tax_id, :string

      timestamps(type: :utc_datetime)
    end

    create unique_index(:merchants, [:api_key])
    create unique_index(:merchants, [:email])
    create index(:merchants, [:onboarding_status])
    create index(:merchants, [:kyc_status])
  end
end
