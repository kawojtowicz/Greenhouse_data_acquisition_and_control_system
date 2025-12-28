#include "ti_drivers_config.h"
#include "string.h"
#include <ti/display/Display.h>
#include "semaphore.h"
#include <ti/sysbios/BIOS.h>
#include <ti/sysbios/knl/Task.h>
#include "zone.h"

#define NUM_ZONES 30
#define NUM_DEVICES 30

extern Display_Handle display;
extern sem_t ipEventSyncObj;

extern uint32_t spiReady;
extern uint8_t txBuf[14];
Zone zones[30] = {0};

uint8_t zNum= 0;
uint8_t zonesCheck = 1;
uint32_t tDevNum;
uint32_t i = 0;
uint32_t j = 0;
uint8_t uid[8];


void* regulatorTask(void* pvParameters)
{
    for (i = 0; i < NUM_ZONES; i++)
    {
        zones[i].zoneID = 0;
        for (j = 0; j < NUM_DEVICES; j++)
        {
            zones[i].tempEndDevices[j].id = 0;
        }
    }

//    zones[0].zoneID = 1;
//    zones[0].tempEndDevices[0].id = 1;
//    zones[0].sensorValues.tmpCelsius = 30.0;
//    zones[0].sensorValues.sensorNodeID = 792660525;
//    zones[0].tempEndDevices[0].downValue = 24.0;
//    zones[0].tempEndDevices[0].upValue = 27.0;
//
//    zones[1].zoneID = 2;
//    zones[1].sensorValues.tmpCelsius = 30.0;
//    zones[1].tempEndDevices[0].id = 3;
//    zones[1].sensorValues.sensorNodeID = 792660525;
//    zones[1].tempEndDevices[0].downValue = 26.0;
//    zones[1].tempEndDevices[0].upValue = 27.0;
//
//    zones[1].tempEndDevices[1].id = 1;
//    zones[1].sensorValues.sensorNodeID = 792660525;
//    zones[1].tempEndDevices[1].downValue = 18.0;
//    zones[1].tempEndDevices[1].upValue = 20.0;
    Display_printf(display, 0, 0, "regulator here\n");

    Task_sleep(500);

    while (1)
    {
        zNum = 0;
        while (zones[zNum].zoneID != 0 && zNum < NUM_ZONES)
            {
                tDevNum = 0;
                while (zones[zNum].tempEndDevices[tDevNum].id != 0 && tDevNum < NUM_DEVICES)
                {
                    if (zones[zNum].sensorValues.tmpCelsius > zones[zNum].tempEndDevices[tDevNum].upValue)
                    {
                        zones[zNum].tempEndDevices[tDevNum].onOff = 0;
                        Display_printf(display, 0, 0, "wylaczono t dev %f \n", zones[zNum].sensorValues.tmpCelsius);

                        uint64_t valueID = zones[zNum].tempEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        txBuf[0] = low & 0xFF;
                        txBuf[1] = (low >> 8) & 0xFF;
                        txBuf[2] = (low >> 16) & 0xFF;
                        txBuf[3] = (low >> 24) & 0xFF;

                        txBuf[4] = high & 0xFF;
                        txBuf[5] = (high >> 8) & 0xFF;
                        txBuf[6] = (high >> 16) & 0xFF;
                        txBuf[7] = (high >> 24) & 0xFF;
                        txBuf[8] = 0;
                    }

                    else if (zones[zNum].sensorValues.tmpCelsius < zones[zNum].tempEndDevices[tDevNum].downValue)
                    {
                        zones[zNum].tempEndDevices[tDevNum].onOff = 1;
//                        Display_printf(display, 0, 0, "wlaczono t dev %f\n", zones[zNum].sensorValues.tmpCelsius);

                        uint64_t valueID = zones[zNum].tempEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        txBuf[0] = low & 0xFF;
                        txBuf[1] = (low >> 8) & 0xFF;
                        txBuf[2] = (low >> 16) & 0xFF;
                        txBuf[3] = (low >> 24) & 0xFF;

                        txBuf[4] = high & 0xFF;
                        txBuf[5] = (high >> 8) & 0xFF;
                        txBuf[6] = (high >> 16) & 0xFF;
                        txBuf[7] = (high >> 24) & 0xFF;
                        txBuf[8] = 1;
                    }
                    else {

//                        uint64_t valueID = 5149013745535275;
                        txBuf[0] = 0;
                        txBuf[1] = 0;
                        txBuf[2] = 0;
                        txBuf[3] = 0;

                        txBuf[4] = 0;
                        txBuf[5] = 0;
                        txBuf[6] = 0;
                        txBuf[7] = 0;
                        txBuf[8] = 0;

//                        Display_printf(display, 0, 0, "temp ok ,\n");
////                                       zones[zNum].sensorValues.tmpCelsius);
                    }

                    tDevNum++;
                }

                tDevNum = 0;
                while (zones[zNum].humEndDevices[tDevNum].id != 0 && tDevNum < NUM_DEVICES)
                {

                    if (zones[zNum].sensorValues.humRH > zones[zNum].humEndDevices[tDevNum].upValue)
                    {
                        zones[zNum].humEndDevices[tDevNum].onOff = 0;
//                        Display_printf(display, 0, 0, "wylaczono h dev %f \n", zones[zNum].sensorValues.humRH);

                        uint64_t valueID = zones[zNum].humEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        txBuf[0] = low & 0xFF;
                        txBuf[1] = (low >> 8) & 0xFF;
                        txBuf[2] = (low >> 16) & 0xFF;
                        txBuf[3] = (low >> 24) & 0xFF;

                        txBuf[4] = high & 0xFF;
                        txBuf[5] = (high >> 8) & 0xFF;
                        txBuf[6] = (high >> 16) & 0xFF;
                        txBuf[7] = (high >> 24) & 0xFF;
                        txBuf[8] = 0;
                    }

                    else if (zones[zNum].sensorValues.humRH < zones[zNum].humEndDevices[tDevNum].downValue)
                    {
                        zones[zNum].humEndDevices[tDevNum].onOff = 1;
                        Display_printf(display, 0, 0, "wlaczono h dev %f, %f\n", zones[zNum].sensorValues.humRH, zones[zNum].humEndDevices[tDevNum].downValue);

                        uint64_t valueID = zones[zNum].humEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        txBuf[0] = low & 0xFF;
                        txBuf[1] = (low >> 8) & 0xFF;
                        txBuf[2] = (low >> 16) & 0xFF;
                        txBuf[3] = (low >> 24) & 0xFF;

                        txBuf[4] = high & 0xFF;
                        txBuf[5] = (high >> 8) & 0xFF;
                        txBuf[6] = (high >> 16) & 0xFF;
                        txBuf[7] = (high >> 24) & 0xFF;
                        txBuf[8] = 1;
                    }
                    else {

//                        uint64_t valueID = 5149013745535275;

                        txBuf[0] = 0;
                        txBuf[1] = 0;
                        txBuf[2] = 0;
                        txBuf[3] = 0;

                        txBuf[4] = 0;
                        txBuf[5] = 0;
                        txBuf[6] = 0;
                        txBuf[7] = 0;
                        txBuf[8] = 0;
//                        Display_printf(display, 0, 0, "temp ok ,\n");
////                                       zones[zNum].sensorValues.tmpCelsius);
                    }

                    tDevNum++;
                }

                tDevNum = 0;
                while (zones[zNum].lightEndDevices[tDevNum].id != 0 && tDevNum < NUM_DEVICES)
                {
                    if (zones[zNum].sensorValues.lightLux > zones[zNum].lightEndDevices[tDevNum].upValue)
                    {
                        zones[zNum].lightEndDevices[tDevNum].onOff = 0;
                        Display_printf(display, 0, 0, "wylaczono l dev %f \n", zones[zNum].sensorValues.lightLux);

                        uint64_t valueID = zones[zNum].lightEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        txBuf[0] = low & 0xFF;
                        txBuf[1] = (low >> 8) & 0xFF;
                        txBuf[2] = (low >> 16) & 0xFF;
                        txBuf[3] = (low >> 24) & 0xFF;

                        txBuf[4] = high & 0xFF;
                        txBuf[5] = (high >> 8) & 0xFF;
                        txBuf[6] = (high >> 16) & 0xFF;
                        txBuf[7] = (high >> 24) & 0xFF;
                        txBuf[8] = 0;
                    }

                    else if (zones[zNum].sensorValues.lightLux < zones[zNum].lightEndDevices[tDevNum].downValue)
                    {
                        zones[zNum].lightEndDevices[tDevNum].onOff = 1;
                        Display_printf(display, 0, 0, "wlaczono l dev %f\n", zones[zNum].sensorValues.lightLux);

                        uint64_t valueID = zones[zNum].lightEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        txBuf[0] = low & 0xFF;
                        txBuf[1] = (low >> 8) & 0xFF;
                        txBuf[2] = (low >> 16) & 0xFF;
                        txBuf[3] = (low >> 24) & 0xFF;

                        txBuf[4] = high & 0xFF;
                        txBuf[5] = (high >> 8) & 0xFF;
                        txBuf[6] = (high >> 16) & 0xFF;
                        txBuf[7] = (high >> 24) & 0xFF;
                        txBuf[8] = 1;
                    }
                    else {

//                        uint64_t valueID = 5149013745535275;

                        txBuf[0] = 0;
                        txBuf[1] = 0;
                        txBuf[2] = 0;
                        txBuf[3] = 0;

                        txBuf[4] = 0;
                        txBuf[5] = 0;
                        txBuf[6] = 0;
                        txBuf[7] = 0;
                        txBuf[8] = 0;
//                        Display_printf(display, 0, 0, "temp ok ,\n");
////                                       zones[zNum].sensorValues.tmpCelsius);
                    }


                    tDevNum++;
                }

                zNum++;
            }
        Task_sleep(2500);

    }


    return(0);
}


