#include "spiQueue.h"
#include <ti/drivers/UART.h>
#include <string.h>
#include <stdlib.h>


Queue_Struct spiQueueStruct;
Queue_Handle spiQueue;
extern UART_Handle uart;

void spiQueueInit(void)
{
    Queue_construct(&spiQueueStruct, NULL);
    spiQueue = Queue_handle(&spiQueueStruct);
}

void spiQueueSend(uint8_t *packet, uint8_t len)
{
    SpiMsg_t *msg = malloc(sizeof(SpiMsg_t));
    memcpy(msg->data, packet, 15);
    Queue_put(spiQueue, &msg->elem);
//    UART_write(uart, "Enqueued SPI packet\n", 20);

}
