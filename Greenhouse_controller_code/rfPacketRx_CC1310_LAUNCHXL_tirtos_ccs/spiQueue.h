#ifndef SPIQUEUE_H_
#define SPIQUEUE_H_

#include <ti/sysbios/knl/Queue.h>

typedef struct {
    Queue_Elem elem;
    uint8_t data[64];
} SpiMsg_t;

extern Queue_Struct spiQueueStruct;
extern Queue_Handle spiQueue;

void spiQueueInit(void);
void spiQueueSend(uint8_t *packet, uint8_t len);

#endif
