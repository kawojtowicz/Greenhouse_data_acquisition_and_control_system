#include "ti_drivers_config.h"
#include "string.h"
#include <ti/display/Display.h>
#include <ti/net/http/httpclient.h>
#include "semaphore.h"
#include <ti/drivers/UART2.h>
#include <ti/drivers/uart2/UART2CC32XX.h>
#include <ti/sysbios/BIOS.h>
#include <ti/sysbios/knl/Task.h>
#include <ti/sysbios/knl/Clock.h>
#include "sensors.h"
#include "spiQueue.h"
#include "zoneList.h"


int controllerID = 3;

extern Display_Handle display;
extern sem_t ipEventSyncObj;
extern char macStr[18];
//extern uint32_t g_msTicks;
//uint32_t lastTick= 0;
int zoneIDs[30];

extern int httpPostHtlLog(char* requsetURI, float temperature, float humidity, int light, uint64_t id_sensor_node, const char* deviceId, uint8_t nodeType);
extern int httpPostAnnounceDevice(const char* deviceId, const char* controllerName);
extern ZoneList httpGetDeviceZones(const char* deviceId);
extern void httpGetFullZones(const char* deviceId);



void* httpHTLPostTask(const char* deviceId)
{



    int status_MAC_post = httpPostAnnounceDevice(macStr, macStr);
    Display_printf(display, 0, 0, " %s\n", macStr);


    httpGetFullZones(macStr);


    while(1) {

        spi_message_t msg;
        mq_receive(spiQueue, (char *)&msg, sizeof(msg), NULL);

        SensorValues sensorValues = convertIntoPhysicalValues(msg.data);





        Display_printf(display, 0, 0, "Temp: %2f Hum: %u Light: %f\n",
                               sensorValues.tmpCelsius, sensorValues.humRH, sensorValues.lightLux);

        int serverStatusCode = 0;
        serverStatusCode = httpPostHtlLog("/htl-logs", sensorValues.tmpCelsius,
                                          sensorValues.humRH,
                                          sensorValues.lightLux,
                                          sensorValues.sensorNodeID, macStr, msg.data[0]);




        Display_printf(display, 0, 0, "HTTP Response Status Code: %d\n", serverStatusCode);
        Task_sleep(5000);

        httpGetFullZones(macStr);

    }

    return(0);
}





//void* dataSendTask(void* pvParameters)
//{
////    clockInit();
//
////    while(1)
////    {
//        lastTick = 0;
//
//        if (g_msTicks - lastTick >= 2)
//        {
//            Display_printf(display, 0, 0,"dataSendTask here! %d\n\r", g_msTicks);
//        }
////    }
//    return(0);
//}


