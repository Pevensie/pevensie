import birl.{type Time}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/option.{type Option}

pub type User(user_metadata) {
  User(
    id: String,
    created_at: Time,
    updated_at: Time,
    deleted_at: Option(Time),
    role: Option(String),
    email: String,
    password_hash: Option(String),
    email_confirmed_at: Option(Time),
    phome_number: Option(String),
    phone_number_confirmed_at: Option(Time),
    last_sign_in: Option(Time),
    app_metadata: Dict(String, Dynamic),
    user_metadata: user_metadata,
    banned_until: Option(Time),
  )
}
