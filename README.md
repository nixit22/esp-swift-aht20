# SwiftAHT20

SwiftAHT20 is a pure-Swift driver for the AHT20 temperature and humidity sensor,
built on top of [SwiftI2C](../SwiftI2C).

## Features

- One-shot temperature and relative-humidity readings.
- Automatic calibration check / initialization on first use.
- Soft-reset support.
- ESP-IDF errors surfaced as Swift typed throws (`throws(Error)`).

## API

### `AHT20`

```swift
let sensor = AHT20(i2cMasterBus: bus)
```

| Method | Description |
|---|---|
| `init(i2cMasterBus:)` | Register the sensor on the given I2C master bus (address `0x38`, 100 kHz). |
| `setup()` | Verify calibration; initialize the sensor if needed. Call once after construction. |
| `reset()` | Soft-reset the sensor and re-initialize. |
| `read() -> (temperature: Float, humidity: Float)` | Trigger a measurement and return °C / %RH. |

`AHT20` is `~Copyable` — no explicit cleanup call is needed; the underlying I2C device is removed automatically in `deinit`. The bus itself is not touched.

## License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
