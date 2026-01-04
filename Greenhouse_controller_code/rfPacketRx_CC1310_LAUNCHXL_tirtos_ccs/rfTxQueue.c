/*
 * rfTxQueue.c
 *
 *  Created on: 4 sty 2026
 *      Author: kawoj
 */



#include "rfTxQueue.h"
#include <ti/sysbios/knl/Queue.h>

Queue_Struct rfTxQueueStruct;
Queue_Handle rfTxQueue;

void rfTxQueueInit(void)
{
    Queue_construct(&rfTxQueueStruct, NULL);
    rfTxQueue = Queue_handle(&rfTxQueueStruct);
}

