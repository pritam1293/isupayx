defmodule Isupayx.Repo do
  use Ecto.Repo,
    otp_app: :isupayx,
    adapter: Ecto.Adapters.SQLite3
end
