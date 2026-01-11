#include "ti_drivers_config.h"
#include "string.h"
#include <ti/display/Display.h>
#include <ti/drivers/GPIO.h>
#include <ti/drivers/Timer.h>
#include <ti/sysbios/BIOS.h>
#include <ti/sysbios/knl/Task.h>
#include "semaphore.h"
#include "spiTxQueue.h"

#define TIMER_PERIOD_MS 5

Timer_Handle timerHandle;
extern Display_Handle display;
spi_tx_message_t msgTx;


extern uint32_t g_msTicks;
extern uint32_t spiReady;
extern uint8_t txBuf[9];

void timerISR(UArg arg)
{
    g_msTicks++;
}


void timerInit(void)
{
    Timer_Params timerParams;
    Timer_Params_init(&timerParams);
    timerParams.period = TIMER_PERIOD_MS * 1000;
    timerParams.periodUnits = Timer_PERIOD_US;
    timerParams.timerMode = Timer_CONTINUOUS_CALLBACK;
    timerParams.timerCallback = timerISR;

    timerHandle = Timer_open(CONFIG_TIMER_0, &timerParams);
    if(timerHandle == NULL)
    {
        Display_printf(display, 0, 0, "Timer init failed\n");
        while(1);
    }

    if (Timer_start(timerHandle) != Timer_STATUS_SUCCESS)
    {
        Display_printf(display, 0, 0, "Timer start failed!\n");
        while(1);
    }
}


void* dataSendTask(void* pvParameters)
{
    timerInit();
    uint32_t lastTick = g_msTicks;

    while(1)
    {
        if(g_msTicks - lastTick >= 100)
        {
            lastTick = g_msTicks;
//            spiReady = 1;
            if (mq_receive(spiTxQueue, (char *)&msgTx, sizeof(msgTx), NULL) > 0)
            {
                memcpy(txBuf, msgTx.data, 9);
                spiReady = 1;

            }
        }

        Task_sleep(50);

    }

    return NULL;
}
