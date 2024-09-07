import gleam/result
import pevensie/drivers.{
  type Connected, type Disabled, type Disconnected, AuthDriver, CacheDriver,
}
import pevensie/internal/auth.{type AuthConfig, AuthConfig}
import pevensie/internal/cache.{type CacheConfig, CacheConfig}

pub type Pevensie(
  user_metadata,
  auth_driver,
  auth_status,
  cache_driver,
  cache_status,
) {
  Pevensie(
    auth_config: AuthConfig(auth_driver, user_metadata, auth_status),
    cache_config: CacheConfig(cache_driver, cache_status),
  )
}

pub fn new() -> Pevensie(
  user_metadata,
  auth_driver,
  Disabled,
  cache_driver,
  Disabled,
) {
  Pevensie(auth.AuthDisabled, cache.CacheDisabled)
}

pub fn with_auth(
  pevensie: Pevensie(
    old_user_metadata,
    old_auth_driver,
    Disabled,
    cache_driver,
    cache_status,
  ),
  auth auth_config: AuthConfig(auth_driver, user_metadata, auth_status),
) -> Pevensie(
  user_metadata,
  auth_driver,
  auth_status,
  cache_driver,
  cache_status,
) {
  let Pevensie(cache_config:, ..) = pevensie
  Pevensie(auth_config:, cache_config:)
}

pub fn connect_auth(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Disconnected,
    cache_driver,
    cache_status,
  ),
) -> Result(
  Pevensie(user_metadata, auth_driver, Connected, cache_driver, cache_status),
  Nil,
) {
  let assert Pevensie(
    AuthConfig(
      driver: auth_driver,
      user_metadata_decoder:,
      user_metadata_encoder:,
      cookie_key:,
    ),
    cache_config,
  ) = pevensie

  auth_driver.connect(auth_driver.driver)
  |> result.map(fn(internal_driver) {
    Pevensie(
      AuthConfig(
        driver: AuthDriver(..auth_driver, driver: internal_driver),
        user_metadata_decoder:,
        user_metadata_encoder:,
        cookie_key:,
      ),
      cache_config:,
    )
  })
}

pub fn disconnect_auth(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    Connected,
    cache_driver,
    cache_status,
  ),
) -> Result(
  Pevensie(user_metadata, auth_driver, Disconnected, cache_driver, cache_status),
  Nil,
) {
  let assert Pevensie(
    AuthConfig(
      driver: auth_driver,
      user_metadata_decoder:,
      user_metadata_encoder:,
      cookie_key:,
    ),
    cache_config,
  ) = pevensie

  auth_driver.disconnect(auth_driver.driver)
  |> result.map(fn(internal_driver) {
    Pevensie(
      AuthConfig(
        driver: AuthDriver(..auth_driver, driver: internal_driver),
        user_metadata_decoder:,
        user_metadata_encoder:,
        cookie_key:,
      ),
      cache_config:,
    )
  })
}

pub fn with_cache(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    auth_status,
    old_cache_driver,
    Disabled,
  ),
  cache_config: CacheConfig(cache_driver, cache_status),
) -> Pevensie(
  user_metadata,
  auth_driver,
  auth_status,
  cache_driver,
  cache_status,
) {
  let Pevensie(auth_config:, ..) = pevensie
  Pevensie(auth_config:, cache_config:)
}

pub fn connect_cache(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    auth_status,
    cache_driver,
    Disconnected,
  ),
) -> Result(
  Pevensie(user_metadata, auth_driver, auth_status, cache_driver, Connected),
  Nil,
) {
  let assert Pevensie(auth_config:, cache_config: CacheConfig(cache_driver)) =
    pevensie

  cache_driver.connect(cache_driver.driver)
  |> result.map(fn(internal_driver) {
    Pevensie(
      auth_config:,
      cache_config: CacheConfig(
        driver: CacheDriver(..cache_driver, driver: internal_driver),
      ),
    )
  })
}

pub fn disconnect_cache(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    auth_status,
    cache_driver,
    Connected,
  ),
) -> Result(
  Pevensie(user_metadata, auth_driver, auth_status, cache_driver, Disconnected),
  Nil,
) {
  let assert Pevensie(auth_config:, cache_config: CacheConfig(cache_driver)) =
    pevensie

  cache_driver.disconnect(cache_driver.driver)
  |> result.map(fn(internal_driver) {
    Pevensie(
      auth_config:,
      cache_config: CacheConfig(
        driver: CacheDriver(..cache_driver, driver: internal_driver),
      ),
    )
  })
}
