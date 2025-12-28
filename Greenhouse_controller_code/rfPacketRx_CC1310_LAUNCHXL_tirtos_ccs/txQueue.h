#ifndef TXQUEUE_H_
#define TXQUEUE_H_

#include <stdint.h>
#include <ti/sysbios/knl/Queue.h>

typedef struct {
    Queue_Elem elem;
    uint8_t data[14];

}txMsg_t;

extern Queue_Struct txQueueStruct;
extern Queue_Handle txQueue;

void txQueueInit(void);

void txQueueSend(uint8_t *packet);

txMsg_t* txQueueReceive(void);

#endif /* TXQUEUE_H_ */
