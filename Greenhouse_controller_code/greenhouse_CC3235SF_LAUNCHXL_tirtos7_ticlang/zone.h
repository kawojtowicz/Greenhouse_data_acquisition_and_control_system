#ifndef ZONE_H_
#define ZONE_H_
#include "sensors.h"
#include "endDevice.h"

typedef struct {
    uint32_t zoneID;
    SensorValues sensorValues;
    EndDevice tempEndDevices[30];
    EndDevice humEndDevices[30];
    EndDevice lightEndDevices[30];
} Zone;

#endif /* ZONE_H_ */
