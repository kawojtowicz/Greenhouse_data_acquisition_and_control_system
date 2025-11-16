/*
 *  ======== greenhouse_controller.c ========
 *  Greenhouse controller application.
 */
#include "ti_drivers_config.h"
#include "string.h"
#include <ti/display/Display.h>
#include <ti/net/http/httpclient.h>
#include "semaphore.h"
#include <ti/drivers/UART2.h>
#include <ti/drivers/uart2/UART2CC32XX.h>

//#define HOSTNAME              "http://www.example.com"
#define HOSTNAME              "http://192.168.0.101:3000"
#define USER_AGENT            "HTTPClient (ARM; TI-RTOS)"
#define HTTP_MIN_RECV         (128)

extern Display_Handle display;
extern sem_t ipEventSyncObj;

extern int httpPostHtlLog(char* requsetURI, float temperature, float humidity, int light, int id_sensor_node);

/*
 *  ======== greenhouseController ========
 */
void* httpTask(void* pvParameters)
{
    Display_printf(display, 0, 0, "Starting Greenhouse Controller \n");

    float temperature = 0;
    float humidity = 0;
    int light = 300;
    int id_sensor_node = 1;
    int serverStatusCode = 0;

    serverStatusCode = httpPostHtlLog("/htl-logs", temperature, humidity, light, id_sensor_node);

    Display_printf(display, 0, 0, "HTTP Response Status Code: %d\n", serverStatusCode);

    return(0);
}
