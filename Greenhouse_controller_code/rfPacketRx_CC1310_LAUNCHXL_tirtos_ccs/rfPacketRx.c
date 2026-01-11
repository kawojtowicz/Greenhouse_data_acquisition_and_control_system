
#include <stdlib.h>

#include <math.h>

#include <ti/drivers/rf/RF.h>
#include <ti/drivers/PIN.h>
#include <ti/display/Display.h>
#include <ti/drivers/UART.h>
#include <string.h>
#include <stdio.h>
#include <ti/drivers/SPI.h>
#include <ti/drivers/GPIO.h>
#include "spiQueue.h"
#include "rfTxQueue.h"
#include <ti/sysbios/knl/Task.h>


/* Driverlib Header files */
#include DeviceFamily_constructPath(driverlib/rf_prop_mailbox.h)

#include "Board.h"

/* Application Header files */
#include "RFQueue.h"
#include "smartrf_settings/smartrf_settings.h"

/* Packet RX Configuration */
#define DATA_ENTRY_HEADER_SIZE 8  /* Constant header size of a Generic Data Entry */
#define MAX_LENGTH             30 /* Max length byte the radio will accept */
#define NUM_DATA_ENTRIES       2  /* NOTE: Only two data entries supported at the moment */
#define NUM_APPENDED_BYTES     2  /* The Data Entries data field will contain:
                                   * 1 Header byte (RF_cmdPropRx.rxConf.bIncludeHdr = 0x1)
                                   * Max 30 payload bytes
                                   * 1 status byte (RF_cmdPropRx.rxConf.bAppendStatus = 0x1) */


/***** Prototypes *****/
static void callback(RF_Handle h, RF_CmdHandle ch, RF_EventMask e);
float HDC2010_tempToFloatCelsius(uint16_t raw);
uint32_t HDC2010_humToIntRelative(uint16_t x);
void rfTxTaskFxn(UArg arg0, UArg arg1);
//void SPI_MasterWrite(uint8_t *txBuf, uint8_t *rxBuf, size_t len);
//int SPI_MasterInit(void);
//extern void* spiTask(void* pvParameters);
extern void spiTaskInit(void);


/***** Variable declarations *****/
static RF_Object rfObject;
RF_Handle rfHandle;
volatile bool rxBusy = false;
UART_Handle uart;
uint8_t exponent;
uint32_t result;
uint16_t hum;
uint8_t humRH;
uint16_t lightLux;
uint16_t tmp;
float tmpCelsius;
uint8_t tmpCelsiusInt;
uint8_t tmpCelsiusFraction;
uint8_t value;
RF_CmdHandle rxHandle;
Queue_Struct rfTxQueueStruct;
Queue_Handle rfTxQueue;

/* Pin driver handle */
static PIN_Handle ledPinHandle;
static PIN_State ledPinState;

///* SPI master handle */
//SPI_Handle spiMaster;
//SPI_Params spiParams;

//pthread_t spiThread = (pthread_t)NULL;

/* Buffer which contains all Data Entries for receiving data.
 * Pragmas are needed to make sure this buffer is 4 byte aligned (requirement from the RF Core) */
#if defined(__TI_COMPILER_VERSION__)
#pragma DATA_ALIGN (rxDataEntryBuffer, 4);
static uint8_t
rxDataEntryBuffer[RF_QUEUE_DATA_ENTRY_BUFFER_SIZE(NUM_DATA_ENTRIES,
                                                  MAX_LENGTH,
                                                  NUM_APPENDED_BYTES)];
#elif defined(__IAR_SYSTEMS_ICC__)
#pragma data_alignment = 4
static uint8_t
rxDataEntryBuffer[RF_QUEUE_DATA_ENTRY_BUFFER_SIZE(NUM_DATA_ENTRIES,
                                                  MAX_LENGTH,
                                                  NUM_APPENDED_BYTES)];
#elif defined(__GNUC__)
static uint8_t
rxDataEntryBuffer[RF_QUEUE_DATA_ENTRY_BUFFER_SIZE(NUM_DATA_ENTRIES,
                                                  MAX_LENGTH,
                                                  NUM_APPENDED_BYTES)]
                                                  __attribute__((aligned(4)));
#else
#error This compiler is not supported.
#endif

/* Receive dataQueue for RF Core to fill in data */
static dataQueue_t dataQueue;
static rfc_dataEntryGeneral_t* currentDataEntry;
static uint8_t packetLength;
static uint8_t* packetDataPointer;


static uint8_t packet[MAX_LENGTH + NUM_APPENDED_BYTES - 1]; /* The length byte is stored in a separate variable */

/* --- TX control (global) --- */
volatile uint8_t g_rfSendFlag = 0;
uint8_t g_rfTxBuffer[30];
uint8_t g_rfTxLen = 0;

/*
 * Application LED pin configuration table:
 *   - All LEDs board LEDs are off.
 */
PIN_Config pinTable[] =
{
    Board_PIN_LED2 | PIN_GPIO_OUTPUT_EN | PIN_GPIO_LOW | PIN_PUSHPULL | PIN_DRVSTR_MAX,
    PIN_TERMINATE
};

/***** Function definitions *****/



void *mainThread(void *arg0)
{
    RF_Params rfParams;
    RF_Params_init(&rfParams);
    Display_init();
    UART_Params uartParams;

    /* Initialize UART */
    UART_init();
    UART_Params_init(&uartParams);
    uartParams.writeDataMode = UART_DATA_TEXT;
    uartParams.readDataMode = UART_DATA_TEXT;
    uartParams.readReturnMode = UART_RETURN_FULL;
    uartParams.baudRate = 115200;

    SPI_init();
    GPIO_init();

    /* Open UART instance defined in Board.h */
    uart = UART_open(Board_UART0, &uartParams);

    if (uart == NULL)
    {
        while (1); // UART init failed
    }


    /* Open LED pins */
    ledPinHandle = PIN_open(&ledPinState, pinTable);
    if (ledPinHandle == NULL)
    {
        while(1);
    }

    /* Open the HOST display for output */
    // display = Display_open(Display_Type_UART, NULL);
    // if (display == NULL) {
    //     while (1);
    // }

    if( RFQueue_defineQueue(&dataQueue,
                            rxDataEntryBuffer,
                            sizeof(rxDataEntryBuffer),
                            NUM_DATA_ENTRIES,
                            MAX_LENGTH + NUM_APPENDED_BYTES))
    {
        /* Failed to allocate space for all data entries */
        while(1);
    }

    spiQueueInit();
    spiTaskInit();
    rfTxQueueInit();

//    txQueueInit();
//    txTaskInit();

    /* Modify CMD_PROP_RX command for application needs */
    /* Set the Data Entity queue for received data */
    RF_cmdPropRx.pQueue = &dataQueue;
    /* Discard ignored packets from Rx queue */
    RF_cmdPropRx.rxConf.bAutoFlushIgnored = 1;
    /* Discard packets with CRC error from Rx queue */
    RF_cmdPropRx.rxConf.bAutoFlushCrcErr = 1;
    /* Implement packet length filtering to avoid PROP_ERROR_RXBUF */
    RF_cmdPropRx.maxPktLen = MAX_LENGTH;
    RF_cmdPropRx.pktConf.bRepeatOk = 1;
    RF_cmdPropRx.pktConf.bRepeatNok = 1;

    /* Request access to the radio */
#if defined(DeviceFamily_CC26X0R2)
    rfHandle = RF_open(&rfObject, &RF_prop, (RF_RadioSetup*)&RF_cmdPropRadioSetup, &rfParams);
#else
    rfHandle = RF_open(&rfObject, &RF_prop, (RF_RadioSetup*)&RF_cmdPropRadioDivSetup, &rfParams);
#endif// DeviceFamily_CC26X0R2

    /* Set the frequency */
    RF_postCmd(rfHandle, (RF_Op*)&RF_cmdFs, RF_PriorityNormal, NULL, 0);


    /* Create rfTx task to monitor g_rfSendFlag */
    {
        Task_Params tparams;
        Task_Params_init(&tparams);
        tparams.stackSize = 2048;
        tparams.priority = 2;
        Task_create(rfTxTaskFxn, &tparams, NULL);
    }

//    /* Enter RX mode and stay forever in RX */
//    RF_EventMask terminationReason = RF_runCmd(rfHandle, (RF_Op*)&RF_cmdPropRx,
//                                               RF_PriorityNormal, &callback,
//                                               RF_EventRxEntryDone);

    rxHandle = RF_postCmd(
        rfHandle,
        (RF_Op*)&RF_cmdPropRx,
        RF_PriorityNormal,
        &callback,
        RF_EventRxEntryDone
    );


    uint32_t cmdStatus = ((volatile RF_Op*)&RF_cmdPropRx)->status;
    switch(cmdStatus)
    {
        case PROP_DONE_OK:
            // Packet received with CRC OK
            break;
        case PROP_DONE_RXERR:
            // Packet received with CRC error
            break;
        case PROP_DONE_RXTIMEOUT:
            // Observed end trigger while in sync search
            break;
        case PROP_DONE_BREAK:
            // Observed end trigger while receiving packet when the command is
            // configured with endType set to 1
            break;
        case PROP_DONE_ENDED:
            // Received packet after having observed the end trigger; if the
            // command is configured with endType set to 0, the end trigger
            // will not terminate an ongoing reception
            break;
        case PROP_DONE_STOPPED:
            // received CMD_STOP after command started and, if sync found,
            // packet is received
            break;
        case PROP_DONE_ABORT:
            // Received CMD_ABORT after command started
            break;
        case PROP_ERROR_RXBUF:
            // No RX buffer large enough for the received data available at
            // the start of a packet
            break;
        case PROP_ERROR_RXFULL:
            // Out of RX buffer space during reception in a partial read
            break;
        case PROP_ERROR_PAR:
            // Observed illegal parameter
            break;
        case PROP_ERROR_NO_SETUP:
            // Command sent without setting up the radio in a supported
            // mode using CMD_PROP_RADIO_SETUP or CMD_RADIO_SETUP
            break;
        case PROP_ERROR_NO_FS:
            // Command sent without the synthesizer being programmed
            break;
        case PROP_ERROR_RXOVF:
            // RX overflow observed during operation
            break;
        default:
            // Uncaught error event - these could come from the
            // pool of states defined in rf_mailbox.h
            while(1);
    }

    while(1);
}

void callback(RF_Handle h, RF_CmdHandle ch, RF_EventMask e)
{
    if (e & RF_EventRxEntryDone)
    {
        /* Toggle pin to indicate RX */
        PIN_setOutputValue(ledPinHandle, Board_PIN_LED2,
                           !PIN_getOutputValue(Board_PIN_LED2));

        /* Get current unhandled data entry */
        currentDataEntry = RFQueue_getDataEntry();

        /* Handle the packet data, located at &currentDataEntry->data:
         * - Length is the first byte with the current configuration
         * - Data starts from the second byte */
        packetLength      = *(uint8_t*)(&currentDataEntry->data);
        packetDataPointer = (uint8_t*)(&currentDataEntry->data + 1);

        /* Copy the payload + the status byte to the packet variable */
        memcpy(packet, packetDataPointer, (packetLength + 1));

        spiQueueSend(packet, packetLength + 1);


        RFQueue_nextEntry();
    }
}


void rfTxTaskFxn(UArg arg0, UArg arg1)
{
    while (1)
    {
        if (!Queue_empty(rfTxQueue))
        {
            RfTxMsg_t *msg = (RfTxMsg_t *)Queue_get(rfTxQueue);

            /* --- STOP RX --- */
            RF_cancelCmd(rfHandle, rxHandle, 0);
            RF_flushCmd(rfHandle, rxHandle, 0);

            /* --- PREPARE TX --- */
            RF_cmdPropTx.pPkt   = msg->data;
            RF_cmdPropTx.pktLen = msg->len;

//            /* DEBUG (opcjonalnie) */
//            char uartBuffer[64];
//            int len = snprintf(
//                uartBuffer,
//                sizeof(uartBuffer),
//                "RF TX: %d %d %d %d %d %d %d %d %d\r\n",
//                msg->data[0], msg->data[1], msg->data[2],
//                msg->data[3], msg->data[4], msg->data[5],
//                msg->data[6], msg->data[7], msg->data[8]
//            );
//            UART_write(uart, uartBuffer, len);

            /* --- SEND TX (blocking) --- */
            RF_runCmd(rfHandle,
                      (RF_Op*)&RF_cmdPropTx,
                      RF_PriorityHigh,
                      NULL,
                      0);

            /* --- RESTART RX --- */
            rxHandle = RF_postCmd(
                rfHandle,
                (RF_Op*)&RF_cmdPropRx,
                RF_PriorityNormal,
                &callback,
                RF_EventRxEntryDone
            );

            /* --- FREE MESSAGE --- */
            free(msg);
        }

        Task_sleep(5);
    }
}

/*
 *  ======== HDC2010_humToIntRelative ========
 *  Convert raw humidity register value to the relative humidity rounded
 *  to the nearest whole number; a range of 0 to 100.
 */
uint32_t HDC2010_humToIntRelative(uint16_t raw)
{
    /* round relative humidity to nearest whole number */
    return ((25 * (uint32_t)raw + 0x2000) >> 14);
}

/*
 *  ======== HDC2010_tempToFloatCelsius ========
 *  Convert temperature to celsius.
 */
float HDC2010_tempToFloatCelsius(uint16_t x)
{
    return ((float)x * (165.0f / 65536.0f) - 40.0f);
}
