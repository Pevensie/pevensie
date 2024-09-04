import birl.{type Time}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/json
import gleam/option.{type Option}
import pevensie/internal/encoder.{type Encoder}

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
    phone_number: Option(String),
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

pub fn user_encoder(
  user: User(user_metadata),
  user_metadata_encoder: Encoder(user_metadata),
) -> json.Json {
  json.object([
    #("id", json.string(user.id)),
    #("created_at", json.string(birl.to_iso8601(user.created_at))),
    #("updated_at", json.string(birl.to_iso8601(user.updated_at))),
    #(
      "deleted_at",
      json.nullable(user.deleted_at |> option.map(birl.to_iso8601), json.string),
    ),
    #("role", json.nullable(user.role, json.string)),
    #("email", json.string(user.email)),
    #("password_hash", json.nullable(user.password_hash, json.string)),
    #(
      "email_confirmed_at",
      json.nullable(
        user.email_confirmed_at |> option.map(birl.to_iso8601),
        json.string,
      ),
    ),
    #("phone_number", json.nullable(user.phone_number, json.string)),
    #(
      "phone_number_confirmed_at",
      json.nullable(
        user.phone_number_confirmed_at |> option.map(birl.to_iso8601),
        json.string,
      ),
    ),
    #(
      "last_sign_in",
      json.nullable(
        user.last_sign_in |> option.map(birl.to_iso8601),
        json.string,
      ),
    ),
    #("app_metadata", app_metadata_to_json(user.app_metadata)),
    #("user_metadata", user_metadata_encoder(user.user_metadata)),
    #(
      "banned_until",
      json.nullable(
        user.banned_until |> option.map(birl.to_iso8601),
        json.string,
      ),
    ),
  ])
}
