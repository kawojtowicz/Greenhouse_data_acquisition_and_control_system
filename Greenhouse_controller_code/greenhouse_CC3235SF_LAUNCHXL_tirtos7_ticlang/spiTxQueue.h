/*
 * spiTxQueue.h
 *
 *  Created on: 6 sty 2026
 *      Author: kawoj
 */

#ifndef SPITXQUEUE_H_
#define SPITXQUEUE_H_


#include <mqueue.h>
#include <stdint.h>

#define SPI_TX_MSG_LEN 9
#define SPI_TX_QUEUE_NAME "/spiTxQueue"

typedef struct {
    uint8_t data[SPI_TX_MSG_LEN];
} spi_tx_message_t;

extern mqd_t spiTxQueue;

void spiTxQueueInit(void);


#endif /* SPITXQUEUE_H_ */
