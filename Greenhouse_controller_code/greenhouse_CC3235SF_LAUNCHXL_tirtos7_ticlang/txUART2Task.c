//#include "ti_drivers_config.h"
//#include "string.h"
//#include <ti/display/Display.h>
//#include "semaphore.h"
//#include <ti/drivers/UART2.h>
//#include <ti/drivers/uart2/UART2CC32XX.h>
//#include <ti/sysbios/BIOS.h>
//#include <ti/sysbios/knl/Task.h>
//
//UART2_Handle uart;
//UART2_Params uartParams;
//
//extern Display_Handle display;
//extern sem_t ipEventSyncObj;
//
//
//extern float temp;
//extern float temp_up;
//extern float temp_down;
//
//void* txUART2Task(void* pvParameters)
//{   Display_printf(display, 0, 0, "init\n");
//    UART2_Params_init(&uartParams);
//    uartParams.baudRate = 115200;
//    uartParams.writeMode = UART2_Mode_BLOCKING;
//    uartParams.readMode  = UART2_Mode_BLOCKING;
//
//    uart = UART2_open(CONFIG_UART2_1, &uartParams);
//    if (uart == NULL) {
//        Display_printf(display, 0, 0, "terror init\n"); // error
//    }
//
//    while(1) {
//        if (temp >= temp_up) {
//
//            Display_printf(display, 0, 0, "too hot %2f \n", temp);
//        }
//        else
//        {
//            Display_printf(display, 0, 0, "not too hot %2f \n", temp);
//        }
//        Task_sleep(5000);
//    }
//
//    return(0);
//}
//
//
//
//
#include "ti_drivers_config.h"
#include "string.h"
#include <ti/display/Display.h>
#include "semaphore.h"
#include <ti/drivers/UART2.h>
#include <ti/sysbios/knl/Task.h>

UART2_Handle uart;
UART2_Params uartParams;

extern Display_Handle display;
extern float temp;
extern float temp_up;
extern float temp_down;

void* txUART2Task(void* pvParameters)
{
    Display_printf(display, 0, 0, "UART init...\n");

    UART2_Params_init(&uartParams);
    uartParams.baudRate  = 115200;
    uartParams.writeMode = UART2_Mode_BLOCKING;
    uartParams.readMode  = UART2_Mode_BLOCKING;

    uart = UART2_open(CONFIG_UART2_1, &uartParams);
    if (uart == NULL) {
        Display_printf(display, 0, 0, "UART failed!\n");
    }

    char msg[64];
    size_t bytesWritten;


    while (1)
    {
        if (temp >= temp_up)
        {
            // wypelnij 14 znaków (resztê spacjami)
            snprintf(msg, 14, "HOT:%6.2f ", temp);
        }
        else
        {
            snprintf(msg, 14, "OK :%6.2f ", temp);
        }

        UART2_write(uart, msg, 14, &bytesWritten);

        Task_sleep(5000);
    }

    return 0;
}
