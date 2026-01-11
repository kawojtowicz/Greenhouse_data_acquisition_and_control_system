#include "ti_drivers_config.h"
#include "string.h"
#include <ti/display/Display.h>
#include "semaphore.h"
#include <ti/sysbios/BIOS.h>
#include <ti/sysbios/knl/Task.h>
#include "zone.h"
#include "spiTxQueue.h"

#define NUM_ZONES 30
#define NUM_DEVICES 10

#define STATE_UNKNOWN 0xFF


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

//unit32_t d;
uint8_t uid[8];
//uint8_t spiReadyInd = 0;



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

//    for (i = 0; i < NUM_ZONES; i++)
//    {
//        for (j = 0; j < NUM_DEVICES; j++)
//        {
//            zones[i].lightEndDevices[j].onOff = 0;
//            zones[i].humEndDevices[j].onOff = 0;
//            zones[i].tempEndDevices[j].onOff = 0;
//        }
//    }


    Display_printf(display, 0, 0, "regulator here\n");

    spi_tx_message_t msgTx;
    memset(&msgTx, 0, sizeof(msgTx));


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

//                        Display_printf(display, 0, 0, "wylaczono t dev %f \n", zones[zNum].sensorValues.tmpCelsius);

                        uint64_t valueID = zones[zNum].tempEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        msgTx.data[0] = low & 0xFF;
                        msgTx.data[1] = (low >> 8) & 0xFF;
                        msgTx.data[2] = (low >> 16) & 0xFF;
                        msgTx.data[3] = (low >> 24) & 0xFF;

                        msgTx.data[4] = high & 0xFF;
                        msgTx.data[5] = (high >> 8) & 0xFF;
                        msgTx.data[6] = (high >> 16) & 0xFF;
                        msgTx.data[7] = (high >> 24) & 0xFF;
                        msgTx.data[8] = 0;

//                        if (zones[zNum].tempEndDevices[tDevNum].onOff != 0)
//                        {
                            zones[zNum].tempEndDevices[tDevNum].onOff = 0;
                            mq_send(spiTxQueue, (char *)&msgTx, sizeof(msgTx), 0);
//                        }

//                        spiReadyInd = 1;
                    }

                    else if (zones[zNum].sensorValues.tmpCelsius < zones[zNum].tempEndDevices[tDevNum].downValue)
                    {

//                        Display_printf(display, 0, 0, "wlaczono t dev %f\n", zones[zNum].sensorValues.tmpCelsius);

                        uint64_t valueID = zones[zNum].tempEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        msgTx.data[0] = low & 0xFF;
                        msgTx.data[1] = (low >> 8) & 0xFF;
                        msgTx.data[2] = (low >> 16) & 0xFF;
                        msgTx.data[3] = (low >> 24) & 0xFF;

                        msgTx.data[4] = high & 0xFF;
                        msgTx.data[5] = (high >> 8) & 0xFF;
                        msgTx.data[6] = (high >> 16) & 0xFF;
                        msgTx.data[7] = (high >> 24) & 0xFF;
                        msgTx.data[8] = 1;

//                        if (zones[zNum].tempEndDevices[tDevNum].onOff != 1)
//                        {
                            zones[zNum].tempEndDevices[tDevNum].onOff = 1;
                            mq_send(spiTxQueue, (char *)&msgTx, sizeof(msgTx), 0);
//                        }


//                        spiReadyInd = 1;
                    }

                    tDevNum++;
                }

                tDevNum = 0;
                while (zones[zNum].humEndDevices[tDevNum].id != 0 && tDevNum < NUM_DEVICES)
                {

                    if (zones[zNum].sensorValues.humRH > zones[zNum].humEndDevices[tDevNum].upValue)
                    {

//                        Display_printf(display, 0, 0, "wylaczono h dev %f \n", zones[zNum].sensorValues.humRH);

                        uint64_t valueID = zones[zNum].humEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        msgTx.data[0] = low & 0xFF;
                        msgTx.data[1] = (low >> 8) & 0xFF;
                        msgTx.data[2] = (low >> 16) & 0xFF;
                        msgTx.data[3] = (low >> 24) & 0xFF;

                        msgTx.data[4] = high & 0xFF;
                        msgTx.data[5] = (high >> 8) & 0xFF;
                        msgTx.data[6] = (high >> 16) & 0xFF;
                        msgTx.data[7] = (high >> 24) & 0xFF;
                        msgTx.data[8] = 0;

//                        if (zones[zNum].humEndDevices[tDevNum].onOff != 0)
//                        {
                            zones[zNum].humEndDevices[tDevNum].onOff = 0;
                            mq_send(spiTxQueue, (char *)&msgTx, sizeof(msgTx), 0);
//                        }

//                        spiReadyInd = 1;
                    }

                    else if (zones[zNum].sensorValues.humRH < zones[zNum].humEndDevices[tDevNum].downValue)
                    {

                        Display_printf(display, 0, 0, "wlaczono h dev %f, %f\n", zones[zNum].sensorValues.humRH, zones[zNum].humEndDevices[tDevNum].downValue);

                        uint64_t valueID = zones[zNum].humEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        msgTx.data[0] = low & 0xFF;
                        msgTx.data[1] = (low >> 8) & 0xFF;
                        msgTx.data[2] = (low >> 16) & 0xFF;
                        msgTx.data[3] = (low >> 24) & 0xFF;

                        msgTx.data[4] = high & 0xFF;
                        msgTx.data[5] = (high >> 8) & 0xFF;
                        msgTx.data[6] = (high >> 16) & 0xFF;
                        msgTx.data[7] = (high >> 24) & 0xFF;
                        msgTx.data[8] = 1;

//                        if (zones[zNum].humEndDevices[tDevNum].onOff != 1)
//                        {
                            zones[zNum].humEndDevices[tDevNum].onOff = 1;
                            mq_send(spiTxQueue, (char *)&msgTx, sizeof(msgTx), 0);
//                        }

//                        spiReadyInd = 1;
                    }

                    tDevNum++;
                }

                tDevNum = 0;
                while (zones[zNum].lightEndDevices[tDevNum].id != 0 && tDevNum < NUM_DEVICES)
                {
                    if (zones[zNum].sensorValues.lightLux > zones[zNum].lightEndDevices[tDevNum].upValue)
                    {

                        Display_printf(display, 0, 0, "wylaczono l dev %f \n", zones[zNum].sensorValues.lightLux);

                        uint64_t valueID = zones[zNum].lightEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        msgTx.data[0] = low & 0xFF;
                        msgTx.data[1] = (low >> 8) & 0xFF;
                        msgTx.data[2] = (low >> 16) & 0xFF;
                        msgTx.data[3] = (low >> 24) & 0xFF;

                        msgTx.data[4] = high & 0xFF;
                        msgTx.data[5] = (high >> 8) & 0xFF;
                        msgTx.data[6] = (high >> 16) & 0xFF;
                        msgTx.data[7] = (high >> 24) & 0xFF;

                        msgTx.data[8] = 2;
//                        if (zones[zNum].lightEndDevices[tDevNum].onOff != 0)
//                        {

//                        }
                        zones[zNum].lightEndDevices[tDevNum].onOff = 0;
                        mq_send(spiTxQueue, (char *)&msgTx, sizeof(msgTx), 0);
//                        spiReadyInd = 1;
                    }

                    else if (zones[zNum].sensorValues.lightLux < zones[zNum].lightEndDevices[tDevNum].downValue)
                    {
                        zones[zNum].lightEndDevices[tDevNum].onOff = 1;
                        Display_printf(display, 0, 0, "wlaczono l dev %f\n", zones[zNum].sensorValues.lightLux);

                        uint64_t valueID = zones[zNum].lightEndDevices[tDevNum].id;

                        uint32_t low  = (uint32_t)(valueID & 0xFFFFFFFF);
                        uint32_t high = (uint32_t)((valueID >> 32) & 0xFFFFFFFF);

                        msgTx.data[0] = low & 0xFF;
                        msgTx.data[1] = (low >> 8) & 0xFF;
                        msgTx.data[2] = (low >> 16) & 0xFF;
                        msgTx.data[3] = (low >> 24) & 0xFF;

                        msgTx.data[4] = high & 0xFF;
                        msgTx.data[5] = (high >> 8) & 0xFF;
                        msgTx.data[6] = (high >> 16) & 0xFF;
                        msgTx.data[7] = (high >> 24) & 0xFF;
                        msgTx.data[8] = 1;
                        mq_send(spiTxQueue, (char *)&msgTx, sizeof(msgTx), 0);
//                        spiReadyInd = 1;
                    }

                    tDevNum++;
                }

                zNum++;

            }
        Task_sleep(5000);

    }


    return(0);
}


