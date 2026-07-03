// Copyright (c) 2026 Nicolas Christe
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import I2C
import Platform

private let log = Logger(tag: "AHT20")

private enum Registers: UInt8 {
    case status = 0x71
    case initCmd = 0xBE
    case measure = 0xAC
    case reset = 0xBA
}

public struct AHT20: ~Copyable {

    private let device: I2CMasterBus.Device

    /// Aborts on failure — intended for boot-time static allocation.
    public init(i2cMasterBus: borrowing I2CMasterBus) {
        do {
            self.device = try i2cMasterBus.addDevice(deviceAddress: 0x38, sclSpeedHz: 100_000)
        } catch {
            log.e("AHT20 init failed: \(error.name)")
            fatalError()
        }
    }

    public func setup() throws(Error) {
        log.d("Setting up AHT20")
        // Wait 40ms after power up before reading
        vTaskDelay(.init(ms: 40))

        // Read status. AHT20 returns the status byte as the first byte of any read,
        // so a 1-byte read with no preceding command is the documented way to get it.
        let status = try device.receive(length: 1, timeoutMs: 100)[0]
        if (status & 0x08) == 0 {
            log.i("AHT20 not calibrated, initializing")
            try device.transmit(data: [Registers.initCmd.rawValue, 0x08, 0x00], timeoutMs: 100)
            vTaskDelay(.init(ms: 10))
        } else {
            log.d("AHT20 calibrated")
        }
    }

    public func reset() throws(Error) {
        log.d("Resetting AHT20")
        try device.transmit(data: [Registers.reset.rawValue], timeoutMs: 100)
        vTaskDelay(.init(ms: 20))
        try setup()
    }

    public func read() throws(Error) -> (temperature: Float, humidity: Float) {
        log.d("Reading AHT20 sensor data")

        // Trigger measurement
        // Command 0xAC, parameter 0x33, 0x00
        try device.transmit(data: [Registers.measure.rawValue, 0x33, 0x00], timeoutMs: 100)

        // Wait for measurement to complete (80ms)
        vTaskDelay(.init(ms: 80))

        // Read 7 bytes: state, humidity[19:12], humidity[11:4], humidity[3:0] | temp[19:16],
        // temp[15:8], temp[7:0], CRC8.
        let data = try device.receive(length: 7, timeoutMs: 100)

        let status = data[0]
        if (status & 0x80) != 0 {
            log.w("AHT20 busy")
            throw Error.espError(ESP_ERR_TIMEOUT)
        }

        if crc8(data.prefix(6)) != data[6] {
            log.w("AHT20 CRC mismatch")
            throw Error.espError(ESP_ERR_INVALID_CRC)
        }

        // Humidity is 20-bit: byte1, byte2, byte3[7:4]
        let hRaw = (UInt32(data[1]) << 12) | (UInt32(data[2]) << 4) | (UInt32(data[3]) >> 4)
        let humidity = Float(hRaw) / Float(1 << 20) * 100.0

        // Temperature is 20-bit: byte3[3:0], byte4, byte5
        let tRaw = ((UInt32(data[3] & 0x0F)) << 16) | (UInt32(data[4]) << 8) | UInt32(data[5])
        let temperature = Float(tRaw) / Float(1 << 20) * 200.0 - 50.0

        return (temperature: temperature, humidity: humidity)
    }
}

// CRC8 with polynomial 0x31, initial value 0xFF (per AHT20 datasheet).
private func crc8(_ bytes: some Sequence<UInt8>) -> UInt8 {
    var crc: UInt8 = 0xFF
    for byte in bytes {
        crc ^= byte
        for _ in 0..<8 {
            if (crc & 0x80) != 0 {
                crc = (crc << 1) ^ 0x31
            } else {
                crc <<= 1
            }
        }
    }
    return crc
}
