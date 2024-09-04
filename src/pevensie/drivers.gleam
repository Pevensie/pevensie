import gleam/dynamic.{type Decoder}
import gleam/option.{type Option}
import pevensie/internal/encoder.{type Encoder}
import pevensie/internal/user.{type User, type UserInsert, type UserUpdate}

pub type Connected

pub type Disconnected

pub type Disabled

/// A function that connects the auth driver. This may
/// set up any connections or perform any other setup
/// required to make the driver ready to use.
type ConnectFunction(auth_driver) =
  fn(auth_driver) -> Result(auth_driver, Nil)

/// A function that disconnects the auth driver. This may
/// tear down any connections or perform any other cleanup
/// required once the driver is no longer needed.
type DisconnectFunction(auth_driver) =
  fn(auth_driver) -> Result(auth_driver, Nil)

/// A function that retrieves a user by the given field and value.
/// The first string argument is the field to search by, and the
/// second string argument is the value to search for.
type GetUserFunction(auth_driver, user_metadata) =
  fn(auth_driver, String, String, Decoder(user_metadata)) ->
    Result(User(user_metadata), Nil)

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

pub type AuthDriver(driver, user_metadata) {
  AuthDriver(
    driver: driver,
    connect: ConnectFunction(driver),
    disconnect: DisconnectFunction(driver),
    get_user: GetUserFunction(driver, user_metadata),
    insert_user: InsertUserFunction(driver, user_metadata),
    update_user: UpdateUserFunction(driver, user_metadata),
    delete_user: DeleteUserFunction(driver, user_metadata),
  )
}

type CacheStoreFunction(cache_driver) =
  fn(cache_driver, String, String, String, Option(Int)) -> Result(Nil, Nil)

type CacheGetFunction(cache_driver) =
  fn(cache_driver, String, String) -> Result(Option(String), Nil)

type CacheDeleteFunction(cache_driver) =
  fn(cache_driver, String, String) -> Result(Nil, Nil)

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
