#include <ti/sysbios/knl/Task.h>
#include <ti/drivers/SPI.h>
#include <ti/drivers/GPIO.h>
#include <stdlib.h>
#include <ti/display/Display.h>
#include <ti/drivers/UART.h>
#include <stdio.h>


#include "spiQueue.h"
#include "rfTxQueue.h"
#include "Board.h"

#define SPI_TASK_STACK 2048

static uint8_t spiStack[SPI_TASK_STACK];
uint8_t val;
extern UART_Handle uart;
extern uint8_t g_rfSendFlag;
extern uint8_t g_rfTxBuffer[30];
extern uint8_t g_rfTxLen;


void spiTaskFxn(UArg arg0, UArg arg1)
{
    SPI_Handle spi;
    SPI_Params spiParams;

    SPI_Params_init(&spiParams);
    spiParams.bitRate = 1000000;
    spiParams.mode = SPI_MASTER;

    spi = SPI_open(CC1310_LAUNCHXL_SPI0, &spiParams);


    GPIO_setConfig(CC1310_LAUNCHXL_GPIO_TOGGLE_STATE,
                           GPIO_CFG_IN_NOPULL | GPIO_CFG_IN_INT_NONE);

    while (1)
    {
        if (!Queue_empty(spiQueue))
        {
            SpiMsg_t *msg = (SpiMsg_t*)Queue_get(spiQueue);

            uint8_t rxBuf[32] = {0};
            SPI_Transaction t;
            t.count = 15;
            t.txBuf = msg->data;
            t.rxBuf = rxBuf;

            SPI_transfer(spi, &t);

            free(msg);
        }


        val = GPIO_read(CC1310_LAUNCHXL_GPIO_TOGGLE_STATE);

        if (val == 1)
        {

            uint8_t rxBuf[32] = {0};
            uint8_t Buf[15] = {2};
            SPI_Transaction t;
            t.count = 15;
            t.txBuf = Buf;
            t.rxBuf = rxBuf;

            SPI_transfer(spi, &t);

//            char uartBuffer[32];
//            int len = snprintf(uartBuffer, sizeof(uartBuffer),
//                               " %d %d %d %d %d %d %d %d\n", rxBuf[0], rxBuf[1], rxBuf[2], rxBuf[3], rxBuf[4], rxBuf[5], rxBuf[6], rxBuf[7], rxBuf[8] );
//            UART_write(uart, uartBuffer, len);

//            if (!(rxBuf[0] == 2 &&
//                  rxBuf[1] == 0 &&
//                  rxBuf[2] == 0 &&
//                  rxBuf[3] == 0 &&
//                  rxBuf[4] == 0 &&
//                  rxBuf[5] == 0 &&
//                  rxBuf[6] == 0 &&
//                  rxBuf[7] == 0 &&
//                  rxBuf[8] == 0))
//            {
//                g_rfTxLen = 9;
//                // Copy SPI data into RF TX buffer                // or the actual length of meaningful data
//                memcpy(g_rfTxBuffer, rxBuf, g_rfTxLen);
//
//                // Trigger RF TX
//                g_rfSendFlag = 1;
//
//            }
            static const uint8_t emptyFrame[9] = { 0,0,0,0,0,0,0,0,0};

            if (memcmp(rxBuf, emptyFrame, 9) != 0)
            {
                RfTxMsg_t *msg = malloc(sizeof(RfTxMsg_t));
                if (msg != NULL)
                {
                    if (rxBuf[8] == 2)
                    {
                        rxBuf[8] = 0;
                    }
                    msg->len = 9;
                    memcpy(msg->data, rxBuf, 9);

                    Queue_put(rfTxQueue, &msg->_elem);
                }
            }


            while (val == 1)
            {
                val = GPIO_read(CC1310_LAUNCHXL_GPIO_TOGGLE_STATE);

            }


        }

        Task_sleep(100);

    }
}

void spiTaskInit(void)
{
    Task_Params params;
    Task_Params_init(&params);

    params.stack = spiStack;
    params.stackSize = SPI_TASK_STACK;
    params.priority = 3;

    Task_create(spiTaskFxn, &params, NULL);
}

