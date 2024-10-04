//// Pevensie makes it simple to add authentication to your Gleam applications.
//// Currently only email/password authentication is supported, but more
//// authentication methods (OAuth2, passkeys, etc.) are planned for the future.
////
//// While you can use Pevensie Auth without the rest of the Pevensie ecosystem,
//// it's better used as a foundation on which to build a Pevensie-driven
//// application. Other Pevensie modules are designed to integrate well with
//// Pevensie Auth, so you can use them without worrying about authentication.
////
//// ## Getting Started
////
//// Pevensie Auth is driver-based, like many other Pevensie modules. This means
//// that you need to choose a driver for your authentication needs. Pevensie
//// provides in-house drivers, but hopefully in the future other drivers will
//// be available.
////
//// To get started, you'll need to create a type to represent your user
//// metadata (see [`pevensie/user`](/pevensie/user) for more details), as well
//// as a decoder and encoder for that type.
////
//// ```gleam
//// import gleam/dynamic.{type DecodeError}
//// import gleam/json
////
//// pub type UserMetadata {
////   UserMetadata(name: String, age: Int)
//// }
////
//// pub fn user_metadata_decoder() -> Result(UserMetadata, List(DecodeError)) {
////   // ...
//// }
////
//// pub fn user_metadata_encoder(user_metadata: UserMetadata) -> json.Json {
////   // ...
//// }
//// ```
////
//// Next, you'll need to create a driver of your choice. Here, we'll be using the
//// first-party Postgres driver, but you can use any driver you like.
////
//// ```gleam
//// import pevensie/drivers/postgres.{type PostgresConfig}
////
//// pub fn main() {
////   let config = PostgresConfig(
////     ..postgres.default_config(),
////     database: "my_database",
////   )
////   let driver = postgres.new_auth_driver(config)
////   // ...
//// }
//// ```
////
//// Now that you have a driver, you can create a Pevensie Auth instance. This
//// instance will act as your entrypoint to the Pevensie Auth API.
////
//// ```gleam
//// import pevensie/auth.{type PevensieAuth}
////
//// pub fn main() {
////   // ...
////   let driver = postgres.new_auth_driver(config)
////   let pevensie_auth = auth.new(
////     driver:,
////     user_metadata_decoder:,
////     user_metadata_encoder:,
////     cookie_key: "super secret signing key",
////   )
////   // ...
//// }
//// ```
////
//// Make sure to call [`connect`](/pevensie/auth.html#connect) on your
//// Pevensie Auth instance before using it. This allows your driver to
//// perform any setup required, such as creating a database connection pool.
//// Different drivers may require different setup and at different times
//// (at the start of the application, once per request, etc.). See the
//// documentation for your chosen driver for more information.
////
//// Finally, create your first user using
//// [`create_user_with_email`](/pevensie/auth.html#create_user_with_email).
////
//// ```gleam
//// import pevensie/auth.{type PevensieAuth}
////
//// pub fn main() {
////   // ...
////   let assert Ok(pevensie_auth) = auth.connect(pevensie_auth)
////   auth.create_user_with_email(
////     pevensie_auth,
////     "lucy@pevensie.dev",
////     "password",
////     UserMetadata(name: "Lucy Pevensie", age: 8),
////   )
////   // ...
//// }
//// ```
////
//// ### Logging In Users
////
//// Pevensie Auth provides individual functions for verifying user credentials
//// and creating sessions. However, it also provides a convenience function
//// for logging in users, which will create a session and update the user's
//// last sign in time.
////
//// ```gleam
//// import pevensie/auth.{type PevensieAuth}
////
//// pub fn main() {
////   // ...
////   let assert Ok(#(session, user)) = auth.log_in_user(
////     pevensie_auth,
////     "lucy@pevensie.dev",
////     "password",
////     Some(net.parse_ip_address("127.1")),
////     None,
////   )
////   // ...
//// }
//// ```
////
//// ## Drivers
////
//// Pevensie Auth is designed to be driver-agnostic, so you can use any driver
//// you like. The drivers provided with Pevensie are:
////
//// - [`postgres`](/pevensie/drivers/postgres.html) - A driver for PostgreSQL
////
//// The hope is that other first- and third-party drivers will be available
//// in the future.
////
//// > Note: database-based drivers will require migrations to be run before
//// > using them. See the documentation for your chosen driver for more
//// > information.
////
//// ## Session Management
////
//// Pevensie Auth provides a simple API for managing sessions. Sessions are
//// managed using opaque session IDs, which are tied to a user ID and optionally
//// an IP address and user agent.
////
//// Sessions are created using the
//// [`create_session`](/pevensie/auth.html#create_session) function, and
//// retrieved using the [`get_session`](/pevensie/auth.html#get_session)
//// function. Sessions can be deleted using the
//// [`delete_session`](/pevensie/auth.html#delete_session) function. Expired
//// sessions may be deleted automatically by the driver, or they may be
//// deleted manually using the
//// [`delete_session`](/pevensie/auth.html#delete_session) function.
////
//// ```gleam
//// import gleam/option.{None, Some}
//// import pevensie/auth.{type PevensieAuth}
//// import pevensie/net
////
//// pub fn main() {
////   // ...
////   let session = auth.create_session(
////     pevensie_auth,
////     user.id,
////     Some(net.parse_ip_address("127.1")),
////     None,
////     Some(24 * 60 * 60),
////   )
////   // ...
//// }
//// ```
////
//// ### Cookies
////
//// Session tokens should be provided as cookies, and Pevensie Auth provides
//// convenience functions for signing and verifying cookies. You can choose not
//// to sign cookies, but it's generally recommended to do so.

import argus
import birl
import gleam/dict
import gleam/dynamic.{type Decoder}
import gleam/erlang/process
import gleam/io
import gleam/option.{type Option, None, Some}
import gleam/result
import gleam/string
import pevensie/drivers.{
  type ConnectFunction, type Connected, type DisconnectFunction,
  type Disconnected,
}
import pevensie/internal/encode.{type Encoder}
import pevensie/net.{type IpAddress}
import pevensie/session.{type Session}
import pevensie/user.{
  type User, type UserInsert, type UserSearchFields, type UserUpdate, Set,
  UserInsert, UserSearchFields, UserUpdate, default_user_search_fields,
  default_user_update,
}

// ----- PevensieAuth ----- //

/// The entrypoint to the Pevensie Auth API. This type is used when using
/// the majority of the functions in `pevensie/auth`.
///
/// You must connect your Pevensie Auth instance before using it. This
/// allows your driver to perform any setup required, such as creating
/// a database connection pool.
///
/// Create a new `PevensieAuth` instance using the
/// [`new`](#new) function.
///
/// ```gleam
/// import pevensie/auth.{type PevensieAuth}
///
/// pub fn main() {
///   let pevensie_auth = auth.new(
///     postgres.new_auth_driver(postgres.default_config()),
///     user_metadata_decoder,
///     user_metadata_encoder,
///     "super secret signing key",
///   )
///   // ...
/// }
/// ```
pub opaque type PevensieAuth(driver, user_metadata, connected) {
  PevensieAuth(
    driver: AuthDriver(driver, user_metadata),
    user_metadata_decoder: Decoder(user_metadata),
    user_metadata_encoder: Encoder(user_metadata),
    cookie_key: String,
  )
}

/// Creates a new [`PevensieAuth`](#PevensieAuth) instance.
///
/// The `driver` argument is the driver to use for authentication. This
/// should be the driver that you've created using the `new_auth_driver`
/// function.
///
/// The `user_metadata_decoder` and `user_metadata_encoder` arguments are
/// used to decode and encode user metadata. These should be the inverse
/// of each other, and should be able to handle both decoding and encoding
/// user metadata to JSON.
///
/// The `cookie_key` argument is used to sign and verify cookies. It should
/// be a long, random string. It's recommended to use a secret key from
/// a cryptographically secure source, and store it in a secure location.
pub fn new(
  driver driver: AuthDriver(driver, user_metadata),
  user_metadata_decoder user_metadata_decoder: Decoder(user_metadata),
  user_metadata_encoder user_metadata_encoder: Encoder(user_metadata),
  cookie_key cookie_key: String,
) -> PevensieAuth(driver, user_metadata, Disconnected) {
  PevensieAuth(
    driver:,
    user_metadata_decoder:,
    user_metadata_encoder:,
    cookie_key:,
  )
}

/// Runs setup for your chosen auth driver and returns a connected
/// [`PevensieAuth`](#PevensieAuth) instance.
///
/// This function must be called before using any other functions in
/// the Pevensie Auth API. Attempting to use the API before calling
/// `connect` will result in a compile error.
///
/// ```gleam
/// import pevensie/auth.{type PevensieAuth}
///
/// pub fn main() {
///   // ...
///   let assert Ok(pevensie_auth) = auth.connect(pevensie_auth)
///   // ...
/// }
/// ```
pub fn connect(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Disconnected),
) -> Result(PevensieAuth(auth_driver, user_metadata, Connected), Nil) {
  let PevensieAuth(
    driver: auth_driver,
    user_metadata_decoder:,
    user_metadata_encoder:,
    cookie_key:,
  ) = pevensie_auth

  auth_driver.connect(auth_driver.driver)
  |> result.map(fn(internal_driver) {
    PevensieAuth(
      driver: AuthDriver(..auth_driver, driver: internal_driver),
      user_metadata_decoder:,
      user_metadata_encoder:,
      cookie_key:,
    )
  })
}

/// Runs teardown for your chosen auth driver and returns a disconnected
/// [`PevensieAuth`](#PevensieAuth) instance.
pub fn disconnect(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
) -> Result(PevensieAuth(auth_driver, user_metadata, Disconnected), Nil) {
  let PevensieAuth(
    driver: auth_driver,
    user_metadata_decoder:,
    user_metadata_encoder:,
    cookie_key:,
  ) = pevensie_auth

  auth_driver.disconnect(auth_driver.driver)
  |> result.map(fn(internal_driver) {
    PevensieAuth(
      driver: AuthDriver(..auth_driver, driver: internal_driver),
      user_metadata_decoder:,
      user_metadata_encoder:,
      cookie_key:,
    )
  })
}

// ----- User CRUD Functions ----- //

/// Retrieves a list of users based on the given search fields.
///
/// The `filters` argument is a [`UserSearchFields`](/pevensie/user.html#UserSearchFields)
/// type that contains the search fields to use. The `UserSearchFields` type
/// contains a number of fields, such as `id`, `email`, and `phone_number`.
/// Each field can be set to a list of values to search for, or to `None` to
/// search for all values.
///
/// Drivers may handle search fields differently, so see the documentation
/// for your chosen driver for more information.
pub fn list_users(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  limit limit: Int,
  offset offset: Int,
  filters filters: UserSearchFields,
) -> Result(List(User(user_metadata)), Nil) {
  let PevensieAuth(driver:, user_metadata_decoder:, ..) = pevensie_auth

  driver.list_users(
    driver.driver,
    limit,
    offset,
    filters,
    user_metadata_decoder,
  )
}

/// Fetch a single user by ID.
///
/// Errors if exactly one user is not found.
pub fn get_user_by_id(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  user_id user_id: String,
) -> Result(User(user_metadata), Nil) {
  let PevensieAuth(driver:, user_metadata_decoder:, ..) = pevensie_auth

  use users <- result.try(driver.list_users(
    driver.driver,
    // We only want one user, but we need to pass a limit of 2 so we can
    // error if the search returns more than one user.
    2,
    0,
    UserSearchFields(..default_user_search_fields(), id: Some([user_id])),
    user_metadata_decoder,
  ))

  case users {
    [user] -> Ok(user)
    _ -> Error(Nil)
  }
}

/// Fetch a single user by email.
///
/// Errors if exactly one user is not found.
pub fn get_user_by_email(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  email email: String,
) -> Result(User(user_metadata), Nil) {
  let PevensieAuth(driver:, user_metadata_decoder:, ..) = pevensie_auth

  use users <- result.try(driver.list_users(
    driver.driver,
    // We only want one user, but we need to pass a limit of 2 so we can
    // error if the search returns more than one user.
    2,
    0,
    UserSearchFields(..default_user_search_fields(), email: Some([email])),
    user_metadata_decoder,
  ))

  case users {
    [user] -> Ok(user)
    _ -> Error(Nil)
  }
}

fn hash_password(password: String) {
  argus.hasher()
  |> argus.hash(password, argus.gen_salt())
}

/// Fetch a single user by email and password.
///
/// Errors if exactly one user is not found, or if the password for the
/// user is incorrect.
pub fn get_user_by_email_and_password(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  email email: String,
  password password: String,
) -> Result(User(user_metadata), Nil) {
  use user <- result.try(get_user_by_email(pevensie_auth, email))
  case argus.verify(user.password_hash |> option.unwrap(""), password) {
    Ok(True) -> Ok(user)
    _ -> Error(Nil)
  }
}

/// Create a new user with the given email and password.
pub fn create_user_with_email(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  email email: String,
  password password: String,
  user_metadata user_metadata: user_metadata,
) -> Result(User(user_metadata), Nil) {
  let PevensieAuth(driver:, user_metadata_decoder:, user_metadata_encoder:, ..) =
    pevensie_auth

  // TODO: Handle errors
  let assert Ok(hashed_password) = hash_password(password)

  driver.insert_user(
    driver.driver,
    UserInsert(
      role: None,
      email: email,
      password_hash: Some(hashed_password.encoded_hash),
      email_confirmed_at: None,
      phone_number: None,
      phone_number_confirmed_at: None,
      last_sign_in: None,
      app_metadata: user.new_app_metadata(dict.new()),
      user_metadata: user_metadata,
    ),
    user_metadata_decoder,
    user_metadata_encoder,
  )
}

/// Update a user by ID. See [`UserUpdate`](/pevensie/user.html#UserUpdate)
/// for more information on how to provide the fields to be updated.
///
/// ```gleam
/// import pevensie/auth.{type PevensieAuth}
///
/// pub fn main() {
///   // ...
///   let assert Ok(user) = auth.update_user(
///     pevensie_auth,
///     user.id,
///     UserUpdate(..user.default_user_update(), email: Set("new_email@example.com")),
///   )
///   // ...
/// }
/// ```
///
/// > Note: if updating the user's password, you should use the
/// > [`set_user_password`](#set_user_password) function instead in order
/// > to hash the password before storing it in the database.
pub fn update_user(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  user_id user_id: String,
  user_update user_update: UserUpdate(user_metadata),
) -> Result(User(user_metadata), Nil) {
  let PevensieAuth(driver:, user_metadata_decoder:, user_metadata_encoder:, ..) =
    pevensie_auth

  driver.update_user(
    driver.driver,
    "id",
    user_id,
    user_update,
    user_metadata_decoder,
    user_metadata_encoder,
  )
}

/// Update a user's role.
pub fn set_user_role(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  user_id user_id: String,
  role role: Option(String),
) -> Result(User(user_metadata), Nil) {
  update_user(
    pevensie_auth,
    user_id,
    UserUpdate(..default_user_update(), role: Set(role)),
  )
}

/// Update a user's email.
pub fn set_user_email(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  user_id user_id: String,
  email email: String,
) -> Result(User(user_metadata), Nil) {
  update_user(
    pevensie_auth,
    user_id,
    UserUpdate(..default_user_update(), email: Set(email)),
  )
}

/// Update a user's password.
///
/// If a password is provided, it will be hashed using Argon2 before being
/// stored in the database. If no password is provided, the user's password
/// will be set to `null`.
pub fn set_user_password(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  user_id user_id: String,
  password password: Option(String),
) -> Result(User(user_metadata), Nil) {
  let password_hash_result = case password {
    None -> Ok(None)
    Some(password) ->
      hash_password(password)
      |> result.replace_error(Nil)
      |> result.map(fn(hashes) { Some(hashes.encoded_hash) })
  }

  use password_hash <- result.try(password_hash_result)
  update_user(
    pevensie_auth,
    user_id,
    UserUpdate(..default_user_update(), password_hash: Set(password_hash)),
  )
}

// ----- Session CRUD Functions ----- //

/// Create a new session for a user. If IP address or user agent are provided,
/// they will be stored alongside the session, and must be provided when
/// fetching the session later.
///
/// You can optionally set a TTL for the session, which will cause the session
/// to expire. Set `ttl_seconds` to `None` to never expire the session.
///
/// You can optionally delete any other active sessions for the user. This may
/// be useful if you want to ensure that a user can only have one active
/// session at a time.
pub fn create_session(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  user_id user_id: String,
  ip ip: Option(IpAddress),
  user_agent user_agent: Option(String),
  ttl_seconds ttl_seconds: Option(Int),
  delete_other_sessions delete_other_sessions: Bool,
) -> Result(Session, Nil) {
  let PevensieAuth(driver:, ..) = pevensie_auth

  driver.create_session(
    driver.driver,
    user_id,
    ip,
    user_agent,
    ttl_seconds,
    delete_other_sessions,
  )
}

/// Fetch a session by ID. If IP address or user agent were provided when
/// the session was created, they should be provided here as well.
pub fn get_session(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  session_id session_id: String,
  ip ip: Option(IpAddress),
  user_agent user_agent: Option(String),
) -> Result(Option(Session), Nil) {
  let PevensieAuth(driver:, ..) = pevensie_auth

  driver.get_session(driver.driver, session_id, ip, user_agent)
}

/// Delete a session by ID.
pub fn delete_session(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  session_id session_id: String,
) -> Result(Nil, Nil) {
  let PevensieAuth(driver:, ..) = pevensie_auth

  driver.delete_session(driver.driver, session_id)
}

// ----- User Authentication ----- //

/// Log in a user using email and password.
///
/// Assuming credentials are valid, this function will create a new session
/// for the user, and update the user's last sign in time.
///
/// Uses a session TTL of 24 hours, and does not delete any other sessions
/// for the user.
pub fn log_in_user(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  email email: String,
  password password: String,
  ip ip: Option(IpAddress),
  user_agent user_agent: Option(String),
) -> Result(#(Session, User(user_metadata)), Nil) {
  use user <- result.try(get_user_by_email_and_password(
    pevensie_auth,
    email,
    password,
  ))

  process.start(
    fn() {
      update_user(
        pevensie_auth,
        user.id,
        UserUpdate(..default_user_update(), last_sign_in: Set(Some(birl.now()))),
      )
    },
    False,
  )

  create_session(
    pevensie_auth,
    user.id,
    ip,
    user_agent,
    Some(24 * 60 * 60),
    False,
  )
  |> result.map(fn(session) { #(session, user) })
}

// ----- Cookies ----- //

/// Create a signed cookie for a session.
pub fn create_session_cookie(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  session session: Session,
) -> Result(String, Nil) {
  let PevensieAuth(cookie_key:, ..) = pevensie_auth
  io.println("Creating hash")
  use hash <- result.try(encode.sha256_hash(session.id, cookie_key))
  io.println("Hash created")
  Ok(session.id <> "|" <> hash)
}

// TODO: Improve errors
/// Validate a signed cookie for a session. Returns the session ID if the
/// cookie is valid.
pub fn validate_session_cookie(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  cookie cookie: String,
) -> Result(String, Nil) {
  let PevensieAuth(cookie_key:, ..) = pevensie_auth
  let cookie_parts = string.split(cookie, "|")
  case cookie_parts {
    [session_id, hash_string] -> {
      use new_hash <- result.try(encode.sha256_hash(session_id, cookie_key))
      case new_hash == hash_string {
        True -> Ok(session_id)
        False -> Error(Nil)
      }
    }
    _ -> Error(Nil)
  }
}

pub type OneTimeTokenType {
  PasswordReset
}

pub fn create_one_time_token(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  user_id user_id: String,
  token_type token_type: OneTimeTokenType,
  ttl_seconds ttl_seconds: Int,
) -> Result(String, Nil) {
  let PevensieAuth(driver:, ..) = pevensie_auth

  driver.create_one_time_token(driver.driver, user_id, token_type, ttl_seconds)
}

pub fn validate_one_time_token(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  user_id user_id: String,
  token_type token_type: OneTimeTokenType,
  token token: String,
) -> Result(Nil, Nil) {
  let PevensieAuth(driver:, ..) = pevensie_auth

  driver.validate_one_time_token(driver.driver, user_id, token_type, token)
}

pub fn use_one_time_token(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  user_id user_id: String,
  token_type token_type: OneTimeTokenType,
  token token: String,
) -> Result(Nil, Nil) {
  let PevensieAuth(driver:, ..) = pevensie_auth

  driver.use_one_time_token(driver.driver, user_id, token_type, token)
}

pub fn delete_one_time_token(
  pevensie_auth: PevensieAuth(auth_driver, user_metadata, Connected),
  user_id user_id: String,
  token_type token_type: OneTimeTokenType,
  token token: String,
) -> Result(Nil, Nil) {
  let PevensieAuth(driver:, ..) = pevensie_auth

  driver.delete_one_time_token(driver.driver, user_id, token_type, token)
}

// ----- Auth Driver ----- //

pub type AuthDriver(driver, user_metadata) {
  AuthDriver(
    driver: driver,
    connect: ConnectFunction(driver),
    disconnect: DisconnectFunction(driver),
    list_users: ListUsersFunction(driver, user_metadata),
    insert_user: InsertUserFunction(driver, user_metadata),
    update_user: UpdateUserFunction(driver, user_metadata),
    delete_user: DeleteUserFunction(driver, user_metadata),
    get_session: GetSessionFunction(driver),
    create_session: CreateSessionFunction(driver),
    delete_session: DeleteSessionFunction(driver),
    create_one_time_token: CreateOneTimeTokenFunction(driver),
    validate_one_time_token: ValidateOneTimeTokenFunction(driver),
    use_one_time_token: UseOneTimeTokenFunction(driver),
    delete_one_time_token: DeleteOneTimeTokenFunction(driver),
  )
}

/// A function that retrieves users based on the given search fields.
/// The first `Int` argument is the number of users to limit the search to,
/// the second `Int` argument is the offset to use, and the `UserSearchFields`
/// argument is the search fields to use.
type ListUsersFunction(auth_driver, user_metadata) =
  fn(auth_driver, Int, Int, UserSearchFields, Decoder(user_metadata)) ->
    Result(List(User(user_metadata)), Nil)

/// A function that updates a user by the given field and value.
/// The first string argument is the field to update, the second
/// string argument is the value to update it to, and the third
/// argument is the user update to apply.
type UpdateUserFunction(auth_driver, user_metadata) =
  fn(
    auth_driver,
    String,
    String,
    UserUpdate(user_metadata),
    Decoder(user_metadata),
    Encoder(user_metadata),
  ) ->
    Result(User(user_metadata), Nil)

/// A function that inserts a user into the database.
/// The first argument is the user to insert, the second
/// argument is the decoder to use to decode the user metadata,
/// and the third argument is the encoder to use to encode the
/// user metadata.
type InsertUserFunction(auth_driver, user_metadata) =
  fn(
    auth_driver,
    UserInsert(user_metadata),
    Decoder(user_metadata),
    Encoder(user_metadata),
  ) ->
    Result(User(user_metadata), Nil)

/// A function that deletes a user from the database.
/// The first string argument is the field to delete by, and the
/// second string argument is the value to delete it by.
type DeleteUserFunction(auth_driver, user_metadata) =
  fn(auth_driver, String, String, Decoder(user_metadata)) ->
    Result(User(user_metadata), Nil)

/// A function that gets a session by ID.
/// Args:
///   - auth_driver: The auth driver to use.
///   - session_id: The ID of the session to get.
///   - ip: The IP address of the user.
///   - user_agent: The user agent of the user.
type GetSessionFunction(auth_driver) =
  fn(auth_driver, String, Option(IpAddress), Option(String)) ->
    Result(Option(Session), Nil)

/// A function that creates a new session for a user.
/// Args:
///   - auth_driver: The auth driver to use.
///   - user_id: The ID of the user to create a session for.
///   - ip: The IP address of the user.
///   - user_agent: The user agent of the user.
///   - ttl_seconds: The number of seconds the session should last for.
///   - delete_other_sessions: Whether to delete any other sessions for the user.
type CreateSessionFunction(auth_driver) =
  fn(auth_driver, String, Option(IpAddress), Option(String), Option(Int), Bool) ->
    Result(Session, Nil)

/// A function that deletes a session by ID.
/// Args:
///   - auth_driver: The auth driver to use.
///   - session_id: The ID of the session to delete.
type DeleteSessionFunction(auth_driver) =
  fn(auth_driver, String) -> Result(Nil, Nil)

/// A function that creates a one time token.
/// Args:
///   - auth_driver: The auth driver to use.
///   - user_id: The ID of the user to create the token for.
///   - token_type: The type of token to create.
///   - ttl_seconds: The number of seconds the token should last for.
///
/// Returns: the token
type CreateOneTimeTokenFunction(auth_driver) =
  fn(auth_driver, String, OneTimeTokenType, Int) -> Result(String, Nil)

/// A function that checks if a one time token is still active.
/// Args:
///   - auth_driver: The auth driver to use.
///   - user_id: The ID of the user to check the token for.
///   - token_type: The type of token to create.
///   - token: The token to check.
type ValidateOneTimeTokenFunction(auth_driver) =
  fn(auth_driver, String, OneTimeTokenType, String) -> Result(Nil, Nil)

/// A function that uses a one time token, erroring if invalid.
/// Args:
///   - auth_driver: The auth driver to use.
///   - user_id: The ID of the user using the token.
///   - token_type: The type of token to use.
///   - token: The token to check.
type UseOneTimeTokenFunction(auth_driver) =
  fn(auth_driver, String, OneTimeTokenType, String) -> Result(Nil, Nil)

/// A function that deletes a one time token.
/// Args:
///   - auth_driver: The auth driver to use.
///   - user_id: The ID of the user to delete the token for.
///   - token_type: The type of token to delete.
///   - token: The token to delete.
type DeleteOneTimeTokenFunction(auth_driver) =
  fn(auth_driver, String, OneTimeTokenType, String) -> Result(Nil, Nil)
