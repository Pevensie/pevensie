//// TODO: `pevensie/user` module docs

import birl.{type Time}
import gleam/dict.{type Dict}
import gleam/dynamic.{type Dynamic}
import gleam/json
import gleam/option.{type Option, None}
import pevensie/internal/encoder.{type Encoder}

// ----- User ----- //

/// Internal metadata used by Pevensie. Contains user information such as
/// OAuth tokens, etc.
pub opaque type AppMetadata {
  // TODO: Properly type app_metadata
  AppMetadata(Dict(String, Dynamic))
}

@internal
pub fn new_app_metadata(data: Dict(String, Dynamic)) -> AppMetadata {
  AppMetadata(data)
}

/// Pevensie's user type. Users can be identified by ID, email, or phone number - 
/// all of which are unique.
///
/// Fields:
/// - `id`: The user's ID (unique).
/// - `created_at`: The time the user was created.
/// - `updated_at`: The time the user was last updated.
/// - `deleted_at`: The time the user was deleted.
/// - `role`: The user's role. This can be set to any string, and is not used by
///   Pevensie.
/// - `email`: The user's email address.
/// - `password_hash`: The user's hashed password.
/// - `app_metadata`: Pevensie's internal metadata about the user.
/// - `user_metadata`: Custom user metadata, such as username, avatar, etc. This
///   is not used by Pevensie.
/// - `last_sign_in`: The time the user last signed in.
///
/// The `user_metadata` field is a generic field that can be used to store any
/// custom data about the user. When creating a `PevensieAuth` instance, you will
/// need to provide a `user_metadata` decoder and encoder.
///
/// A few fields currently unused, but will be used in the future:
/// - `email_confirmed_at`: The time the user confirmed their email address.
/// - `phone_number_confirmed_at`: The time the user confirmed their phone number.
/// - `banned_until`: The time the user will be banned.
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
    app_metadata: AppMetadata,
    user_metadata: user_metadata,
    banned_until: Option(Time),
  )
}

/// A user to be inserted into the database. See `User` for fields.
pub type UserInsert(user_metadata) {
  UserInsert(
    role: Option(String),
    email: String,
    password_hash: Option(String),
    email_confirmed_at: Option(Time),
    phone_number: Option(String),
    phone_number_confirmed_at: Option(Time),
    last_sign_in: Option(Time),
    app_metadata: AppMetadata,
    user_metadata: user_metadata,
  )
}

/// A field to be updated in the database. Use the `Set` constructor to set a
/// field to a value, and the `Ignore` constructor to leave the field unchanged.
pub type UpdateField(a) {
  Set(a)
  Ignore
}

/// A user to be updated in the database. See `User` for fields.
///
/// Can be constructed more easily using `default_user_update`.
pub type UserUpdate(user_metadata) {
  UserUpdate(
    role: UpdateField(Option(String)),
    email: UpdateField(String),
    password_hash: UpdateField(Option(String)),
    email_confirmed_at: UpdateField(Option(Time)),
    phone_number: UpdateField(Option(String)),
    phone_number_confirmed_at: UpdateField(Option(Time)),
    last_sign_in: UpdateField(Option(Time)),
    app_metadata: UpdateField(AppMetadata),
    user_metadata: UpdateField(user_metadata),
  )
}

/// A set of fields to use when searching for or listing users.
/// Each field can be set to a list of values to search for, to
/// search for multiple values at once.
///
/// Different drivers may handle search fields differently. See the
/// documentation for the specific driver for more information.
///
/// Can be constructed more easily using `default_user_search_fields`.
pub type UserSearchFields {
  UserSearchFields(
    id: Option(List(String)),
    email: Option(List(String)),
    phone_number: Option(List(String)),
  )
}

/// A convenience function to create a `UserUpdate` with all fields set to
/// `Ignore`.
///
/// ```gleam
/// import pevensie/auth
/// import pevensie/user.{Set}
///
/// fn main() {
///   // ...
///   auth.update_user(
///     pevensie_auth,
///     user.id,
///     user.UserUpdate(
///       ..user.default_user_update(),
///       email: Set("new_email@example.com"),
///     ),
///   )
/// }
/// ```
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

/// A convenience function to create a `UserSearchFields` with all fields set to
/// `None`.
///
/// ```gleam
/// import pevensie/user
///
/// fn main() {
///   // ...
///   user.list_users(
///     pevensie_auth,
///     user.UserSearchFields(
///       ..user.default_user_search_fields(),
///       email: Some(["isaac@example.com"]),
///     ),
///   )
/// }
/// ```
pub fn default_user_search_fields() -> UserSearchFields {
  UserSearchFields(id: None, email: None, phone_number: None)
}

/// Encodes an `AppMetadata` value to JSON.
pub fn app_metadata_encoder(_app_metadata: AppMetadata) -> json.Json {
  // TODO: Properly type app_metadata
  json.object([])
}

/// Encodes a `User` value to JSON.
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
    #("app_metadata", app_metadata_encoder(user.app_metadata)),
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
