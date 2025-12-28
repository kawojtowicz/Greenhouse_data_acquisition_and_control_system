#include "sensors.h"
#include <stdint.h>
#include <math.h>


uint32_t HDC2010_humToIntRelative(uint16_t raw)
{
    return ((25 * (uint32_t)raw + 0x2000) >> 14);
}

float HDC2010_tempToFloatCelsius(uint16_t x)
{
    return ((float)x * (165.0f / 65536.0f) - 40.0f);
}

SensorValues convertIntoPhysicalValues(uint8_t *packet)
{
    SensorValues values;
    uint8_t exponent = (packet[9] >> 4) & 0x0F;
    uint8_t value = packet[9] & 0x0F;
    uint16_t result = (value << 8) | packet[10];

    exponent = (packet[9] >> 4) & 0x0F;
    value = packet[9] & 0x0F;
    result  = (value << 8) | packet[10];

    values.lightLux = 0.01 * pow(2, exponent) * result;

    uint16_t hum = (packet[12] << 8) | packet[11];
    values.humRH = HDC2010_humToIntRelative(hum);

    uint16_t tmp = (packet[14] << 8) | packet[13];
    values.tmpCelsius = HDC2010_tempToFloatCelsius(tmp);

    uint64_t valueID = 0;
    for(int i = 8; i >= 1; i--) {
        valueID = (valueID << 8) | packet[i];
    }
    values.sensorNodeID = valueID;
//    uint64_t valueID = 0;
//
//    for (int i = 0; i < 8; i++) {
//        valueID |= ((uint64_t)packet[i]) << (8 * i);
//    }

    values.sensorNodeID = valueID;


    return values;
}
