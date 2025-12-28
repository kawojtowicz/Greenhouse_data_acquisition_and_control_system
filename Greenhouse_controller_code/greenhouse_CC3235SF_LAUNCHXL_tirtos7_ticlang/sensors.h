#ifndef SENSORS_H
#define SENSORS_H

#include <stdint.h>

typedef struct {
    float lightLux;
    uint32_t humRH;
    float tmpCelsius;
    uint64_t sensorNodeID;
} SensorValues;

SensorValues convertIntoPhysicalValues(uint8_t *packet);

#endif
