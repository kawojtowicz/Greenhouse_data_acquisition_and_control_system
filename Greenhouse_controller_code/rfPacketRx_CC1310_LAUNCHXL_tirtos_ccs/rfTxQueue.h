/*
 * rfTxQueue.h
 *
 *  Created on: 4 sty 2026
 *      Author: kawoj
 */

#ifndef RFTXQUEUE_H_
#define RFTXQUEUE_H_

#include <ti/sysbios/knl/Queue.h>
#include <stdint.h>

#define RF_TX_MAX_LEN 9

typedef struct {
    Queue_Elem _elem;
    uint8_t len;
    uint8_t data[RF_TX_MAX_LEN];
} RfTxMsg_t;

extern Queue_Struct rfTxQueueStruct;
extern Queue_Handle rfTxQueue;

void rfTxQueueInit(void);

#endif

