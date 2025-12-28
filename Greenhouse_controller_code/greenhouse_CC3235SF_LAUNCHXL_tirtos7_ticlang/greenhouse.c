#include <ti/drivers/net/wifi/simplelink.h>
#include <ti/drivers/net/wifi/slnetifwifi.h>
#include <ti/display/Display.h>
#include <ti/drivers/SPI.h>
#include <ti/drivers/GPIO.h>
#include <ti/sysbios/knl/Clock.h>
#include <string.h>
#include <stdio.h>

#include "ti_drivers_config.h"
#include "pthread.h"
#include "semaphore.h"
#include "spiQueue.h"

#define APPLICATION_NAME                      "GREENHOUSE CONTROLLER"
#define DEVICE_ERROR                          ("Device error, please refer \"DEVICE ERRORS CODES\" section in errors.h")
#define WLAN_ERROR                            ("WLAN error, please refer \"WLAN ERRORS CODES\" section in errors.h")
#define SL_STOP_TIMEOUT                       (200)
#define SPAWN_TASK_PRIORITY                   (9)
#define SPAWN_STACK_SIZE                      (4096)
#define HTL_POST_TASK_STACK_SIZE              (6144)
#define TX_UART2_TASK_STACK_SIZE              (2048)
#define TASK_STACK_SIZE                       (2048)
#define SLNET_IF_WIFI_PRIO                    (5)
#define SLNET_IF_WIFI_NAME                    "CC32xx"
/* AP SSID */
//#define SSID_NAME                             "TP-LINK_D7CF"
#define SSID_NAME                             "Orange_Swiatlowod_D330"
//#define SSID_NAME                             "browar perla"

//#define SSID_NAME                             "A35"

/* Security type could be SL_WLAN_SEC_TYPE_WPA_WPA2 */
#define SECURITY_TYPE                         SL_WLAN_SEC_TYPE_WPA_WPA2

/* Password of the secured AP */
//#define SECURITY_KEY                          "73173281"
#define SECURITY_KEY                          "Q64xHphN2AsTn6tcaZ"
//#define SECURITY_KEY                          "samsung123"
//#define SECURITY_KEY                          "PolskaGurom1337"


pthread_t spiThread = (pthread_t)NULL;
pthread_t regulatorThread = (pthread_t)NULL;
pthread_t dataSendThread = (pthread_t)NULL;
pthread_t spiGPIOThread = (pthread_t)NULL;
pthread_t txUART2Thread = (pthread_t)NULL;
pthread_t httpHTLPostThread = (pthread_t)NULL;
pthread_t spawn_thread = (pthread_t)NULL;

int32_t mode;
Display_Handle display;
uint8_t deviceMAC[6] = {0};
volatile uint32_t g_msTicks = 0;
uint32_t spiReady = 0;
char macStr[18];
char resp[256];

uint8_t rxBuf[15], txBuf[15];

extern void* spiTask(void* pvParameters);
extern void* regulatorTask(void* pvParameters);
extern void* dataSendTask(void* pvParameters);
extern void* spiGPIOTask(void* pvParameters);
extern void* txUART2Task(void* pvParameters);
extern void* httpHTLPostTask(void* pvParameters);
extern int32_t ti_net_SlNet_initConfig();


void SPI_StartReceive(uint8_t *rxBuf, uint8_t *txBuf, size_t len);
void SPI_HandleMasterMessage(uint8_t *rxBuf, size_t len);

/*
 *  ======== printError ========
 */
void printError(char *errString,
                int code)
{
    Display_printf(display, 0, 0, "Error! code = %d, Description = %s\n", code,
                   errString);
    while(1)
    {
        ;
    }
}

void getMAC(uint8_t *mac)
{
    uint8_t len = 6;
    int ret = sl_NetCfgGet(SL_NETCFG_MAC_ADDRESS_GET, NULL, &len, mac);
    if (ret < 0) {
        Display_printf(display, 0, 0, "Blad pobierania MAC: %d\n", ret);
    }
}

void SimpleLinkNetAppEventHandler(SlNetAppEvent_t *pNetAppEvent)
{
    int32_t             status = 0;
    pthread_attr_t      pAttrs;
    struct sched_param  priParam;

    if(pNetAppEvent == NULL)
    {
        return;
    }

    switch(pNetAppEvent->Id)
    {
    case SL_NETAPP_EVENT_IPV4_ACQUIRED:
    case SL_NETAPP_EVENT_IPV6_ACQUIRED:
        status = ti_net_SlNet_initConfig();
        if (0 != status) {
            Display_printf(display, 0, 0, "Failed to initialize SlNetSock\n\r");
        }

        if (mode != ROLE_AP) {
            Display_printf(display, 0, 0,"[NETAPP EVENT] IP Acquired: ...\n\r");

            usleep(100000); // 100 ms

            pthread_attr_init(&pAttrs);
            priParam.sched_priority = 3;
            pthread_attr_setschedparam(&pAttrs, &priParam);
            pthread_attr_setstacksize(&pAttrs, TASK_STACK_SIZE);
            status = pthread_create(&spiThread, &pAttrs, spiTask, NULL);
            if (status) { printError("Task create failed (spi)", status); }

            pthread_attr_init(&pAttrs);
            priParam.sched_priority = 1;
            pthread_attr_setschedparam(&pAttrs, &priParam);
            pthread_attr_setstacksize(&pAttrs, 6144);
            status = pthread_create(&httpHTLPostThread, &pAttrs, httpHTLPostTask, NULL);
            if (status) { printError("Task create failed (http)", status); }

            pthread_attr_init(&pAttrs);
            priParam.sched_priority = 2;
            pthread_attr_setschedparam(&pAttrs, &priParam);
            pthread_attr_setstacksize(&pAttrs, TASK_STACK_SIZE);
            status = pthread_create(&dataSendThread, &pAttrs, dataSendTask, NULL);
            if (status) { printError("Task create failed (dataSend)", status); }

            pthread_attr_init(&pAttrs);
            priParam.sched_priority = 2;
            pthread_attr_setschedparam(&pAttrs, &priParam);
            pthread_attr_setstacksize(&pAttrs, 1024);
            status = pthread_create(&spiGPIOThread, &pAttrs, spiGPIOTask, NULL);
            if (status) { printError("Task create failed (spiGPIO)", status); }


            pthread_attr_init(&pAttrs);
            priParam.sched_priority = 5;
            pthread_attr_setschedparam(&pAttrs, &priParam);
            pthread_attr_setstacksize(&pAttrs, TASK_STACK_SIZE);
            status = pthread_create(&regulatorThread, &pAttrs, regulatorTask, NULL);
            if (status) { printError("Task create failed (regulator)", status); }
        }
        break;
    default:
        break;
    }
}

void SimpleLinkFatalErrorEventHandler(SlDeviceFatal_t *slFatalErrorEvent)
{
    /* Unused in this application */
}

void SimpleLinkNetAppRequestMemFreeEventHandler(uint8_t *buffer)
{
    /* Unused in this application */
}

void SimpleLinkNetAppRequestEventHandler(SlNetAppRequest_t *pNetAppRequest,
                                         SlNetAppResponse_t *pNetAppResponse)
{
    /* Unused in this application */
}

void SimpleLinkHttpServerEventHandler(
    SlNetAppHttpServerEvent_t *pHttpEvent,
    SlNetAppHttpServerResponse_t *
    pHttpResponse)
{
    /* Unused in this application */
}

void SimpleLinkWlanEventHandler(SlWlanEvent_t *pWlanEvent)
{
    /* Unused in this application */
}

void SimpleLinkGeneralEventHandler(SlDeviceEvent_t *pDevEvent)
{
    /* Unused in this application */
}


void SimpleLinkSockEventHandler(SlSockEvent_t *pSock)
{
    /* Unused in this application */
}

void Connect(void)
{
    SlWlanSecParams_t secParams = {0};
    int16_t ret = 0;
    secParams.Key = (signed char*)SECURITY_KEY;
    secParams.KeyLen = strlen(SECURITY_KEY);
    secParams.Type = SECURITY_TYPE;
    Display_printf(display, 0, 0, "Connecting to : %s.\r\n",SSID_NAME);
    ret = sl_WlanConnect((signed char*)SSID_NAME, strlen(
                             SSID_NAME), 0, &secParams, 0);
    if(ret)
    {
        printError("Connection failed", ret);
    }
}

/*!
    \brief          Display application banner

    This routine shows application startup display on UART.

    \param          appName    -   points to a string representing application name.


*/
static void DisplayBanner(char * AppName)
{
    Display_printf(display, 0, 0, "\n\n\n\r");
    Display_printf(display, 0, 0,
                   "\t\t *************************"
                   "************************\n\r");
    Display_printf(display, 0, 0, "\t\t            %s Application       \n\r",
                   AppName);
    Display_printf(display, 0, 0,
                   "\t\t **************************"
                   "***********************\n\r");
    Display_printf(display, 0, 0, "\n\n\n\r");
}


void mainThread(void *pvParameters)
{
    int32_t status = 0;
    pthread_attr_t pAttrs_spawn;
    struct sched_param priParam;

    spiQueue = mq_open("/spiHTLQueue", O_CREAT | O_RDWR, 0666, &spiHTLAttr);
    if (spiQueue == -1) {
        Display_printf(display, 0, 0, "Error creating queue\n");
    }


    SPI_init();
    Display_init();
    display = Display_open(Display_Type_UART, NULL);
    if(display == NULL)
    {
        /* Failed to open display driver */
        while(1)
        {
            ;
        }
    }

    GPIO_init();
    GPIO_setConfig(CONFIG_GPIO_0, GPIO_CFG_OUTPUT);


    /* Print Application name */
    DisplayBanner(APPLICATION_NAME);

    /* Start the SimpleLink Host */
    pthread_attr_init(&pAttrs_spawn);
    priParam.sched_priority = SPAWN_TASK_PRIORITY;
    status = pthread_attr_setschedparam(&pAttrs_spawn, &priParam);
    status |= pthread_attr_setstacksize(&pAttrs_spawn, SPAWN_STACK_SIZE);

    status = pthread_create(&spawn_thread, &pAttrs_spawn, sl_Task, NULL);
    if(status)
    {
        printError("Task create failed", status);
    }

    /* Turn NWP on - initialize the device*/
    mode = sl_Start(0, 0, 0);
    if (mode < 0)
    {
        Display_printf(display, 0, 0,"\n\r[line:%d, error code:%d] %s\n\r", __LINE__, mode, DEVICE_ERROR);
    }

    if(mode != ROLE_STA)
    {
        /* Set NWP role as STA */
        mode = sl_WlanSetMode(ROLE_STA);
        if (mode < 0)
        {
            Display_printf(display, 0, 0,"\n\r[line:%d, error code:%d] %s\n\r", __LINE__, mode, WLAN_ERROR);
        }

        /* For changes to take affect, we restart the NWP */
        status = sl_Stop(SL_STOP_TIMEOUT);
        if (status < 0)
        {
            Display_printf(display, 0, 0,"\n\r[line:%d, error code:%d] %s\n\r", __LINE__, status, DEVICE_ERROR);
        }

        mode = sl_Start(0, 0, 0);
        if (mode < 0)
        {
            Display_printf(display, 0, 0,"\n\r[line:%d, error code:%d] %s\n\r", __LINE__, mode, DEVICE_ERROR);
        }
    }

    if(mode != ROLE_STA)
    {
        printError("Failed to configure device to it's default state", mode);
    }

    getMAC(deviceMAC);


    snprintf(macStr, sizeof(macStr), "%02X:%02X:%02X:%02X:%02X:%02X",
             deviceMAC[0], deviceMAC[1], deviceMAC[2],
             deviceMAC[3], deviceMAC[4], deviceMAC[5]);

    Connect();

}

