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

pub type UpdateField(a) {
  Set(a)
  Ignore
}

pub type UserUpdate(user_metadata) {
  UserUpdate(
    role: UpdateField(Option(String)),
    email: UpdateField(String),
    password_hash: UpdateField(Option(String)),
    email_confirmed_at: UpdateField(Option(Time)),
    phone_number: UpdateField(Option(String)),
    phone_number_confirmed_at: UpdateField(Option(Time)),
    last_sign_in: UpdateField(Option(Time)),
    app_metadata: UpdateField(Dict(String, Dynamic)),
    user_metadata: UpdateField(user_metadata),
  )
}

pub fn default_user_update() -> UserUpdate(user_metadata) {
  UserUpdate(
    role: Ignore,
    email: Ignore,
    password_hash: Ignore,
    email_confirmed_at: Ignore,
    phone_number: Ignore,
    phone_number_confirmed_at: Ignore,
    last_sign_in: Ignore,
    app_metadata: Ignore,
    user_metadata: Ignore,
  )
}

pub fn app_metadata_to_json(_app_metadata: Dict(String, Dynamic)) -> json.Json {
  // TODO: Properly type app_metadata
  json.object([])
}
