#include "txQueue.h"
#include <string.h>
#include <stdlib.h>

Queue_Struct txQueueStruct;
Queue_Handle txQueue;

void txQueueInit(void) {

    Queue_construct(&txQueueStruct, NULL);
    txQueue = Queue_handle(&txQueueStruct);
}

void txQueueSend(uint8_t *packet) {
    txMsg_t *msg = malloc(sizeof(txMsg_t));

    memcpy(msg->data, packet, 14);
    Queue_put(txQueue, &msg->elem);

}

txMsg_t* txQueueReceive(void) {

    if (Queue_empty(txQueue)) {
        return NULL;
    }

    Queue_Elem *elem = Queue_get(txQueue);
    return (txMsg_t*) elem;
}
