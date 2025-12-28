#include "spiQueue.h"

struct mq_attr spiHTLAttr = {
    .mq_flags = 0,
    .mq_maxmsg = 10,
    .mq_msgsize = sizeof(spi_message_t),
    .mq_curmsgs = 0
};

mqd_t spiQueue;
