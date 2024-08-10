import gleam/dynamic.{type Decoder}
import pevensie/internal/user.{type User}

pub opaque type Connected {
  Connected
}

pub opaque type Disconnected {
  Disconnected
}

pub opaque type Disabled {
  Disabled
}

type ConnectFunction(auth_driver) =
  fn(auth_driver) -> Result(auth_driver, Nil)

type DisconnectFunction(auth_driver) =
  fn(auth_driver) -> Result(auth_driver, Nil)

type GetUserFunction(auth_driver, user_metadata) =
  fn(auth_driver, String, String, Decoder(user_metadata)) ->
    Result(User(user_metadata), Nil)

pub type AuthDriver(driver, user_metadata) {
  AuthDriver(
    driver: driver,
    connect: ConnectFunction(driver),
    disconnect: DisconnectFunction(driver),
    get_user: GetUserFunction(driver, user_metadata),
  )
}
