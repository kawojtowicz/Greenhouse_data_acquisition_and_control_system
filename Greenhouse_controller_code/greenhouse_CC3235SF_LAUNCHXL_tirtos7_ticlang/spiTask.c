#include "ti_drivers_config.h"
#include "string.h"
#include <ti/display/Display.h>
#include "semaphore.h"
#include <ti/drivers/UART2.h>
#include <ti/drivers/uart2/UART2CC32XX.h>
#include <ti/sysbios/BIOS.h>
#include <ti/sysbios/knl/Task.h>
#include <ti/drivers/SPI.h>
#include <ti/sysbios/knl/Task.h>
#include "spiQueue.h"


extern Display_Handle display;
extern sem_t ipEventSyncObj;

/* SPI slave handle */
SPI_Handle spiSlave;
SPI_Params spiParams;
extern uint32_t spiReady;
extern uint8_t txBuf;


void SPI_SlaveInit(void)
{
    SPI_Params_init(&spiParams);
    spiParams.frameFormat = SPI_POL0_PHA0;
    spiParams.dataSize = 8;
    spiParams.mode = SPI_PERIPHERAL;

    spiSlave = SPI_open(CONFIG_SPI_0, &spiParams);
    if(spiSlave == NULL) {
    Display_printf(display, 0, 0, "Error! spi");
    }
}

void SPI_SlaveReceive(uint8_t *rxBuf, uint8_t *txBuf, size_t len)
{
    SPI_Transaction transaction;
    transaction.count = len;
    transaction.txBuf = txBuf;
    transaction.rxBuf = rxBuf;
    SPI_transfer(spiSlave, &transaction);
}

void* spiTask(void* pvParameters)
{
    spi_message_t msg;
    SPI_init();

    SPI_SlaveInit();
    Task_sleep(50);

    while(1) {

    SPI_SlaveReceive(msg.data, &txBuf, 15);
    Display_printf(display, 0, 0, "sth reveived\n");
    spiReady = 0;
    if (msg.data[0] != 2)
    {
        mq_send(spiQueue, (char *)&msg, sizeof(msg), 0);
    }


    Display_printf(display, 0, 0, "Received SPI data: %d %d %d %d %d %d %d %d %d %d %d %d %d %d %d\n",
                   msg.data[0], msg.data[1], msg.data[2], msg.data[3], msg.data[4], msg.data[5],
                   msg.data[6], msg.data[7], msg.data[8], msg.data[9], msg.data[10], msg.data[11],
                   msg.data[12], msg.data[13], msg.data[14]);
    }

    return(0);
}


