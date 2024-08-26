import pevensie/drivers.{
  type CacheDriver, type Connected, type Disabled, type Disconnected,
}
import pevensie/internal/cache
import pevensie/internal/pevensie.{type Pevensie}

pub fn new_cache_config(
  driver driver: CacheDriver(cache_driver),
) -> cache.CacheConfig(cache_driver, Disconnected) {
  cache.CacheConfig(driver:)
}

pub fn disabled() -> cache.CacheConfig(Nil, Disabled) {
  cache.CacheDisabled
}

pub fn store(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    auth_status,
    cache_driver,
    Connected,
  ),
  resource_type: String,
  key: String,
  value: String,
) -> Result(Nil, Nil) {
  let assert cache.CacheConfig(driver) = pevensie.cache_config

  driver.store(driver.driver, resource_type, key, value)
}

pub fn get(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    auth_status,
    cache_driver,
    Connected,
  ),
  resource_type: String,
  key: String,
) -> Result(String, Nil) {
  let assert cache.CacheConfig(driver) = pevensie.cache_config

  driver.get(driver.driver, resource_type, key)
}

pub fn delete(
  pevensie: Pevensie(
    user_metadata,
    auth_driver,
    auth_status,
    cache_driver,
    Connected,
  ),
  resource_type: String,
  key: String,
) -> Result(Nil, Nil) {
  let assert cache.CacheConfig(driver) = pevensie.cache_config

  driver.delete(driver.driver, resource_type, key)
}
