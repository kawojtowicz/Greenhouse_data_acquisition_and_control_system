#include "ti_drivers_config.h"
#include "string.h"
#include <ti/display/Display.h>
#include "semaphore.h"
#include <ti/drivers/UART2.h>
#include <ti/drivers/uart2/UART2CC32XX.h>
#include <ti/sysbios/BIOS.h>
#include <ti/sysbios/knl/Task.h>
#include <ti/drivers/GPIO.h>
#include <ti/sysbios/knl/Task.h>
#include "spiQueue.h"


extern Display_Handle display;
extern sem_t ipEventSyncObj;

uint32_t checkSpiReady = 0;
extern uint32_t spiReady;

void* spiGPIOTask(void* pvParameters)
{
    while (1)
    {
        GPIO_write(CONFIG_GPIO_0, spiReady);
        Task_sleep(10);
    }

    return 0;
}



