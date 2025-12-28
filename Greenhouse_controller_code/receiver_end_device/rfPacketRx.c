/* Receiver End Device */

#include <ti/drivers/rf/RF.h>
#include <ti/display/Display.h>
#include <ti/drivers/UART.h>
#include <ti/drivers/GPIO.h>
#include <ti/sysbios/knl/Task.h>
#include <ti/devices/cc13x0/inc/hw_memmap.h>
#include <ti/devices/cc13x0/inc/hw_fcfg1.h>
#include <ti/devices/cc13x0/inc/hw_types.h>


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
#define PAYLOAD_LEN            15

/***** Prototypes *****/
static void callback(RF_Handle h, RF_CmdHandle ch, RF_EventMask e);
void rfTxTaskFxn(UArg arg0, UArg arg1);


/***** Variable declarations *****/
static RF_Object rfObject;
RF_Handle rfHandle;
volatile bool rxBusy = false;
UART_Handle uart;
RF_CmdHandle rxHandle;
uint8_t uid[8];
uint8_t checkID = 0;

/* Pin driver handle */
static PIN_Handle ledPinHandle;
static PIN_State ledPinState;

static Display_Handle display;


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
volatile uint8_t g_rfSendFlag = 1;
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

void getUniqueId(uint8_t *uid8)
{
    uint32_t uid_low  = HWREG(FCFG1_BASE + FCFG1_O_MAC_15_4_0);
    uint32_t uid_high = HWREG(FCFG1_BASE + FCFG1_O_MAC_15_4_1);

    uid8[0] = uid_low & 0xFF;
    uid8[1] = (uid_low >> 8) & 0xFF;
    uid8[2] = (uid_low >> 16) & 0xFF;
    uid8[3] = (uid_low >> 24) & 0xFF;

    uid8[4] = uid_high & 0xFF;
    uid8[5] = (uid_high >> 8) & 0xFF;
    uid8[6] = (uid_high >> 16) & 0xFF;
    uid8[7] = (uid_high >> 24) & 0xFF;
}


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

    GPIO_init();

//    /* Open UART instance defined in Board.h */
//    uart = UART_open(Board_UART0, &uartParams);
//
//    if (uart == NULL)
//    {
//        while (1); // UART init failed
//    }


    /* Open LED pins */
    ledPinHandle = PIN_open(&ledPinState, pinTable);
    if (ledPinHandle == NULL)
    {
        while(1);
    }
    getUniqueId(uid);
    memcpy(&g_rfTxBuffer[1], uid, 8);
    int i;
    for (i = 8; i < PAYLOAD_LEN; i++)
    {
        g_rfTxBuffer[1 + i] = 2;
    }
    g_rfTxLen = PAYLOAD_LEN + 1;
//    memcpy(g_rfTxBuffer, uid, 8);

    /* Open the HOST display for output */
     display = Display_open(Display_Type_UART, NULL);
     if (display == NULL) {
         while (1);
     }
//    Display_printf(display,0,0, " %d %d %d %d %d %d %d %d ", uid[0], uid[1], uid[2], uid[3], uid[4], uid[5], uid[6], uid[7]);
    if( RFQueue_defineQueue(&dataQueue,
                            rxDataEntryBuffer,
                            sizeof(rxDataEntryBuffer),
                            NUM_DATA_ENTRIES,
                            MAX_LENGTH + NUM_APPENDED_BYTES))
    {
        /* Failed to allocate space for all data entries */
        while(1);
    }



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


            /* Get current unhandled data entry */
            currentDataEntry = RFQueue_getDataEntry();

            /* Handle the packet data, located at &currentDataEntry->data:
             * - Length is the first byte with the current configuration
             * - Data starts from the second byte */
            packetLength      = *(uint8_t*)(&currentDataEntry->data);
    //        packetDataPointer = (uint8_t*)(&currentDataEntry->data + 1);
            packetDataPointer = (uint8_t*)(&currentDataEntry->data) + 1;


            /* Copy the payload + the status byte to the packet variable */
            memcpy(packet, packetDataPointer, (packetLength + 1));
    //        Display_printf(display, 0, 0, " %d %d %d %d ", packet[0], uid[0], packet[2], uid[2]);

            int i = 0;
            checkID = 0;
            for (i = 0; i < 8; i++)
            {
                if (packet[i] != uid[i])
                {
                    checkID = 1;
                }
            }

            if (checkID == 0)
            {
                /* Toggle pin to indicate RX */
                PIN_setOutputValue(ledPinHandle, Board_PIN_LED2,
                                   packet[8]);
            }

            Display_printf(display,0,0, " %d %d %d %d %d %d %d %d %d", packet[0], packet[1], packet[2], packet[3], packet[4], packet[5], packet[6], packet[7], packet[8]);



            RFQueue_nextEntry();
        }
}


void rfTxTaskFxn(UArg arg0, UArg arg1)
{
    while(1)
    {
        if (g_rfSendFlag)
        {
            g_rfSendFlag = 0;

            // stop RX
            RF_cancelCmd(rfHandle, rxHandle, 0);
            RF_flushCmd(rfHandle, rxHandle, 0);

            // prepare TX
            RF_cmdPropTx.pPkt = g_rfTxBuffer;
            RF_cmdPropTx.pktLen = g_rfTxLen;
//            Display_printf(display,0,0, " %d %d %d %d %d %d %d %d %d %d",g_rfTxBuffer[5], g_rfTxBuffer[6], g_rfTxBuffer[7], g_rfTxBuffer[8], g_rfTxBuffer[9], g_rfTxBuffer[10], g_rfTxBuffer[11], g_rfTxBuffer[12], g_rfTxBuffer[13], g_rfTxBuffer[14]);

            // send TX (blocking)
            RF_runCmd(rfHandle, (RF_Op*)&RF_cmdPropTx,
                      RF_PriorityHigh, NULL, 0);

            // restart RX
            rxHandle = RF_postCmd(rfHandle,
                                  (RF_Op*)&RF_cmdPropRx,
                                  RF_PriorityNormal,
                                  &callback,
                                  RF_EventRxEntryDone);
        }

        Task_sleep(10);
    }
}
