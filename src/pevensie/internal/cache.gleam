import pevensie/drivers.{type CacheDriver}

pub type CacheConfig(driver, connected) {
  CacheConfig(driver: CacheDriver(driver))
  CacheDisabled
}
