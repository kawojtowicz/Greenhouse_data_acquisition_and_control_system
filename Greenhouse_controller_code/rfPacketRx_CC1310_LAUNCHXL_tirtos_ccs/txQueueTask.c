////#include <ti/sysbios/knl/Task.h>
////#include <stdlib.h>
////#include <string.h>
////#include "txQueue.h"
////#include "Board.h"
////#include <ti/drivers/rf/RF.h>
////
////#define TX_TASK_STACK 2048
////static uint8_t txStack[TX_TASK_STACK];
////
////extern RF_Handle rfHandle;
////extern RF_Op RF_cmdPropTx;
////extern RF_Op RF_cmdPropRx;
////
////void txTaskFxn(UArg arg0, UArg arg1)
////{
////    while(1)
////    {
////        if (!Queue_empty(txQueue))
////        {
////            txMsg_t *msg = (txMsg_t*)Queue_get(txQueue);
////
////            RF_cmdPropTx.pPkt = msg->data;
////            RF_cmdPropTx.pktLen = 14;
////
////            if (RF_getCurrentCmd(rfHandle) != RF_cmdPropRx.handle)
////            {
////                RF_EventMask result = RF_postCmd(rfHandle,
////                                                (RF_Op*)&RF_cmdPropTx,
////                                                RF_PriorityNormal,
////                                                NULL, 0);
////                if (result & RF_EventLastCmdDone)
////                {
////                }
////            }
////
////            free(msg);
////        }
////
////        Task_sleep(1);
////    }
////}
////
////void txTaskInit(void)
////{
////    Task_Params params;
////    Task_Params_init(&params);
////
////    params.stack = txStack;
////    params.stackSize = TX_TASK_STACK;
////    params.priority = 2;
////
////    Task_create(txTaskFxn, &params, NULL);
////}
////
//
//#include <ti/sysbios/knl/Task.h>
//#include <stdlib.h>
//#include <string.h>
//#include <stdbool.h>
//#include "txQueue.h"
//#include "Board.h"
//#include <ti/drivers/rf/RF.h>
//#include "smartrf_settings/smartrf_settings.h"
//#include <ti/display/Display.h>
//#include <ti/drivers/UART.h>
//
//#define TX_TASK_STACK 4096
//static uint8_t txStack[TX_TASK_STACK];
//extern UART_Handle uart;
//
//
///* Zmienne globalne z mainThread */
//extern RF_Handle rfHandle;
//extern volatile bool rxBusy;
//extern rfc_CMD_PROP_TX_t RF_cmdPropTx; // CMD_PROP_TX z smartrf_settings
//extern volatile bool rxBusy;           // ustawiana w callbacku RX
//
//void txTaskFxn(UArg arg0, UArg arg1)
//{
////    while (1)
////    {
////
////        if (!Queue_empty(txQueue) && !rxBusy)
////        {
////
////
////            txMsg_t *msg = (txMsg_t*)Queue_get(txQueue);
////            if (msg != NULL)
////            {   char uartBuffer[32];
////                int len;
////
////                len = snprintf(uartBuffer, sizeof(uartBuffer),
////                                    "tx %d %d %d %d %d", msg[3], msg[4], msg[5], msg[6], msg[7]);
////                UART_write(uart, uartBuffer, len);
//////                 Skopiuj dane do pakietu TX
//////                Task_sleep(1);
//////                memcpy(RF_cmdPropTx.pPkt, msg->data, 14);  // pkt[] zamiast data
//////                RF_cmdPropTx.pktLen = 14;
//////                Task_sleep(1000);
//////                free(msg);
//////
//////                // Wyœlij pakiet
//////                RF_postCmd(rfHandle, (RF_Op*)&RF_cmdPropTx, RF_PriorityNormal, NULL, 0);
//////
//////                free(msg);
////            }
////        }
////        if (!Queue_empty(txQueue))
////        {
////            txMsg_t *msg = (txMsg_t*)Queue_get(txQueue);
//////            if(msg != NULL)
//////            {
//////                memcpy(RF_cmdPropTx.pPkt, msg->data, 14);
//////                RF_cmdPropTx.pktLen = 14;
//////
//////                // Wykonaj TX i poczekaj, a¿ siê skoñczy, nie przerywaj¹c RX
//////                RF_CmdHandle txHandle = RF_postCmd(rfHandle,
//////                                                   (RF_Op*)&RF_cmdPropTx,
//////                                                   RF_PriorityNormal,
//////                                                   NULL,
//////                                                   RF_EventLastCmdDone);
//////                // Pend do zakoñczenia TX
//////                RF_pendCmd(rfHandle, txHandle, RF_EventLastCmdDone);
//////
//////                free(msg);
//////            }
////        }
////
////        Task_sleep(100);
////    }
//}
//
//void txTaskInit(void)
//{
//    Task_Params params;
//    Task_Params_init(&params);
//
//    params.stack = txStack;
//    params.stackSize = TX_TASK_STACK;
//    params.priority = 2; // ni¿szy od RX
//
//    Task_create(txTaskFxn, &params, NULL);
//}
