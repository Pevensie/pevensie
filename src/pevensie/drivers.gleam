import gleam/dynamic.{type Decoder}
import gleam/option.{type Option}
import pevensie/internal/encoder.{type Encoder}
import pevensie/net.{type IpAddress}
import pevensie/session.{type Session}
import pevensie/user.{
  type User, type UserInsert, type UserSearchFields, type UserUpdate,
}

// ----- General Driver Bits ----- //

pub type Connected

pub type Disconnected

pub type Disabled

/// A function that connects the driver. This may
/// set up any connections or perform any other setup
/// required to make the driver ready to use.
type ConnectFunction(driver) =
  fn(driver) -> Result(driver, Nil)

/// A function that disconnects the driver. This may
/// tear down any connections or perform any other cleanup
/// required once the driver is no longer needed.
type DisconnectFunction(driver) =
  fn(driver) -> Result(driver, Nil)

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
  )
}

/// A function that retrieves users based on the given search fields.
type ListUsersFunction(auth_driver, user_metadata) =
  fn(auth_driver, UserSearchFields, Decoder(user_metadata)) ->
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

// ----- Cache Driver ----- //

pub type CacheDriver(driver) {
  CacheDriver(
    driver: driver,
    connect: ConnectFunction(driver),
    disconnect: DisconnectFunction(driver),
    store: CacheStoreFunction(driver),
    get: CacheGetFunction(driver),
    delete: CacheDeleteFunction(driver),
  )
}

type CacheStoreFunction(cache_driver) =
  fn(cache_driver, String, String, String, Option(Int)) -> Result(Nil, Nil)

type CacheGetFunction(cache_driver) =
  fn(cache_driver, String, String) -> Result(Option(String), Nil)

type CacheDeleteFunction(cache_driver) =
  fn(cache_driver, String, String) -> Result(Nil, Nil)
