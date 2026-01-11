/*
 * spiTxQueue.c
 *
 *  Created on: 6 sty 2026
 *      Author: kawoj
 */

#include "spiTxQueue.h"
//#include <fcntl.h>
#include <string.h>

mqd_t spiTxQueue;

void spiTxQueueInit(void)
{
    struct mq_attr attr;
    memset(&attr, 0, sizeof(attr));
    attr.mq_maxmsg = 10;
    attr.mq_msgsize = sizeof(spi_tx_message_t);

    spiTxQueue = mq_open(SPI_TX_QUEUE_NAME,
                          O_CREAT | O_RDWR,
                          0644,
                          &attr);
}



