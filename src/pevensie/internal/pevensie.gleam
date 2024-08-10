import gleam/result
import pevensie/drivers.{
  type Connected, type Disabled, type Disconnected, AuthDriver,
}
import pevensie/internal/auth.{type AuthConfig, AuthConfig}

pub type Pevensie(user_metadata, auth_driver, auth_status) {
  Pevensie(auth_config: AuthConfig(auth_driver, user_metadata, auth_status))
}

pub fn new() -> Pevensie(auth_driver, user_metadata, Disabled) {
  Pevensie(auth.AuthDisabled)
}

pub fn with_auth(
  _pevensie: Pevensie(old_auth_driver, old_user_metadata, old_auth_status),
  auth auth_config: AuthConfig(auth_driver, user_metadata, auth_status),
) -> Pevensie(user_metadata, auth_driver, auth_status) {
  Pevensie(auth_config)
}

pub fn connect_auth(
  pevensie: Pevensie(user_metadata, auth_driver, Disconnected),
) -> Result(Pevensie(user_metadata, auth_driver, Connected), Nil) {
  let assert AuthConfig(driver, user_metadata_decoder) = pevensie.auth_config

  driver.connect(driver.driver)
  |> result.map(fn(internal_driver) {
    Pevensie(AuthConfig(
      user_metadata_decoder:,
      driver: AuthDriver(..driver, driver: internal_driver),
    ))
  })
}

pub fn disconnect_auth(
  pevensie: Pevensie(user_metadata, auth_driver, Connected),
) -> Result(Pevensie(user_metadata, auth_driver, Disconnected), Nil) {
  let assert AuthConfig(driver, user_metadata_decoder) = pevensie.auth_config

  driver.disconnect(driver.driver)
  |> result.map(fn(internal_driver) {
    Pevensie(AuthConfig(
      user_metadata_decoder:,
      driver: AuthDriver(..driver, driver: internal_driver),
    ))
  })
}
