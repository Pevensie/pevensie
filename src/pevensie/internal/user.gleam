import birl.{type Time}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/json
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

pub type UserInsert(user_metadata) {
  UserInsert(
    role: Option(String),
    email: String,
    password_hash: Option(String),
    email_confirmed_at: Option(Time),
    phone_number: Option(String),
    phone_number_confirmed_at: Option(Time),
    last_sign_in: Option(Time),
    app_metadata: Dict(String, Dynamic),
    user_metadata: user_metadata,
  )
}

pub fn app_metadata_to_json(_app_metadata: Dict(String, Dynamic)) -> json.Json {
  // TODO: Properly type app_metadata
  json.object([])
}
