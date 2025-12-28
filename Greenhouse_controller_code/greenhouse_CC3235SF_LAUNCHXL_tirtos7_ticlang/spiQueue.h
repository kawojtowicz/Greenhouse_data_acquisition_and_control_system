#ifndef SPIQUEUE_H_
#define SPIQUEUE_H_

#include <mqueue.h>

typedef struct {
    uint8_t data[15];
} spi_message_t;

extern struct mq_attr spiHTLAttr;

extern mqd_t spiQueue;

#endif
