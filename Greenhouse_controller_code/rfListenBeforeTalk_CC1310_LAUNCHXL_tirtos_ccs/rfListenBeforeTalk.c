/*
 * Copyright (c) 2019, Texas Instruments Incorporated
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 *
 * *  Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 *
 * *  Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 *
 * *  Neither the name of Texas Instruments Incorporated nor the names of
 *    its contributors may be used to endorse or promote products derived
 *    from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
 * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
 * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
 * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
 * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
 * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
 * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
 * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
 * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
 * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

/***** Includes *****/
/* Standard C Libraries */
#include <stdlib.h>
#include <math.h>
#include <stdint.h>
#include <ti/devices/cc13x0/inc/hw_memmap.h>
#include <ti/devices/cc13x0/inc/hw_fcfg1.h>
#include <ti/devices/cc13x0/inc/hw_types.h>



/* TI Drivers */
#include <ti/drivers/rf/RF.h>
#include <ti/drivers/PIN.h>

/* Driver Header files */
#include <ti/drivers/GPIO.h>
#include <ti/drivers/I2C.h>
#include <ti/drivers/dpl/ClockP.h>
#include <ti/display/Display.h>

/* Board Header files */
#include "Board.h"

/* Application Header files */
#include "smartrf_settings/smartrf_settings.h"
#include "application_settings.h"

/* I2C Target address */
#define I2C_TARGET_ADDRESS_HDC2010 (0x40)
#define I2C_TARGET_ADDRESS_OPT3001 (0x45)
#define HDC3022_I2C_ADDR      0x44

/* Measurement commands (datasheet) */
#define HDC3022_CMD_MEASURE   0x2400   // High repeatability, clock stretching



/*
 *  ======== HDC Registers ========
 */
#define HDC2010_T_REG       0x00  /* Temperature Result Register for HDC2010 */
#define HDC2010_H_REG       0x02  /* Humidity Result Register for HDC2010 */

#define I2C_TX_PACKET_SIZE_CONFIGURATION_HDC (3)

/*
 *  ======== OPT Registers ========
 */
#define OPT3001_REG         0x00  /* Light Result Register for OPT3001 */

#define I2C_TX_PACKET_SIZE_CONFIGURATION_OPT (3)


/* Measurement configuration code */
uint8_t gTxPacketConfigurationHDC[I2C_TX_PACKET_SIZE_CONFIGURATION_HDC] = {0x0E, 0x60, 0x01};
uint8_t gTxPacketConfigurationOPT[I2C_TX_PACKET_SIZE_CONFIGURATION_OPT] = {0x01, 0xC6, 0x10};

static Display_Handle display;

/* Pin driver handle */
static PIN_Handle ledPinHandle;
static PIN_State ledPinState;

/* Application LED pin configuration table: */
PIN_Config ledPinTable[] =
{
    Board_PIN_LED1 | PIN_GPIO_OUTPUT_EN | PIN_GPIO_LOW | PIN_PUSHPULL | PIN_DRVSTR_MAX,
    PIN_TERMINATE
};

/***** Defines *****/
#define PAYLOAD_LENGTH          30
#define PACKET_INTERVAL_US      200000
/* Number of times the CS command should run when the channel is BUSY */
#define CS_RETRIES_WHEN_BUSY    10
/* The channel is reported BUSY is the RSSI is above this threshold */
#define RSSI_THRESHOLD_DBM      -80
#define IDLE_TIME_US            5000
/* Proprietary Radio Operation Status Codes Number: Operation ended normally */
#define PROP_DONE_OK            0x3400

/***** Prototypes *****/
static void callback(RF_Handle h, RF_CmdHandle ch, RF_EventMask e);
float HDC2010_tempToFloatCelsius(uint16_t raw);
uint32_t HDC2010_humToIntRelative(uint16_t x);
uint8_t hdc3022_crc8(uint8_t *data, uint8_t len);
float HDC3022_rawToCelsius(uint16_t raw);
uint8_t HDC3022_rawToRH(uint16_t raw);
void getUniqueId(uint8_t *idBuf);

/***** Variable declarations *****/
static RF_Object rfObject;
static RF_Handle rfHandle;

static uint8_t packet[PAYLOAD_LENGTH];
static uint16_t seqNumber;

static uint32_t time;

bool opt_ready = false;
uint8_t cfgRegAddr = 0x01;
uint8_t cfgBuf[2];
uint8_t hdcReg = HDC2010_H_REG;
uint8_t HDC2010_selection_flag = 0;
uint8_t HDC3020_selection_flag = 1;

/*
 *  ======== txTaskFunction ========
 */
void *mainThread(void *arg0)
{
    uint8_t         rxBuffer[2];
    I2C_Handle      i2c;
    I2C_Params      i2cParams;
    I2C_Transaction i2cTransaction;
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

    RF_Params rfParams;
    /* Call driver init functions */
    RF_Params_init(&rfParams);
    Display_init();
    GPIO_init();
    I2C_init();

    /* Open LED pins */
    ledPinHandle = PIN_open(&ledPinState, ledPinTable);
    if (ledPinHandle == NULL)
    {
        while(1);
    }

    /* Open the HOST display for output */
    display = Display_open(Display_Type_UART, NULL);
    if (display == NULL) {
        while (1);
    }

    /* Turn on user LED */
    GPIO_write(Board_GPIO_LED0, Board_GPIO_LED_ON);
    Display_printf(display, 0, 0, "Starting the rfListenBeforeTalkAndSendSensorsData_v1 example.");

    /* Create I2C for usage */
    I2C_Params_init(&i2cParams);
    i2cParams.bitRate = I2C_400kHz;
    i2c = I2C_open(Board_I2C_TMP, &i2cParams);
    if (i2c == NULL) {
        Display_printf(display, 0, 0, "Error Initializing I2C\n");
        while (1);
    }
    else {
        Display_printf(display, 0, 0, "I2C Initialized!");
    }

    /* Get device unique id */
    uint8_t uid[8];
    getUniqueId(uid);
    memcpy(&packet[1], uid, 8);

    packet[0] = 1;

    /* Customize the CMD_PROP_TX command for this application */
    RF_cmdPropTx.pktLen = PAYLOAD_LENGTH;
    RF_cmdPropTx.pPkt = packet;
    RF_cmdNop.startTrigger.triggerType = TRIG_ABSTIME;
    RF_cmdNop.startTrigger.pastTrig = 1;

    /* Set up the next pointers for the command chain */
    RF_cmdNop.pNextOp = (rfc_radioOp_t*)&RF_cmdPropCs;
    RF_cmdPropCs.pNextOp = (rfc_radioOp_t*)&RF_cmdCountBranch;
    RF_cmdCountBranch.pNextOp = (rfc_radioOp_t*)&RF_cmdPropTx;
    RF_cmdCountBranch.pNextOpIfOk = (rfc_radioOp_t*)&RF_cmdPropCs;

    /* Customize the API commands with application specific defines */
    RF_cmdPropCs.rssiThr = RSSI_THRESHOLD_DBM;
    RF_cmdPropCs.csEndTime = (IDLE_TIME_US + 150) * 4; /* Add some margin */
    RF_cmdCountBranch.counter = CS_RETRIES_WHEN_BUSY;

    /* Request access to the radio */
#if defined(DeviceFamily_CC26X0R2)
    rfHandle = RF_open(&rfObject, &RF_prop, (RF_RadioSetup*)&RF_cmdPropRadioSetup, &rfParams);
#else
    rfHandle = RF_open(&rfObject, &RF_prop, (RF_RadioSetup*)&RF_cmdPropRadioDivSetup, &rfParams);
#endif// DeviceFamily_CC26X0R2

    /* Set the frequency */
    RF_postCmd(rfHandle, (RF_Op*)&RF_cmdFs, RF_PriorityNormal, NULL, 0);

    /* Get current time */
    time = RF_getCurrentTime();

    /* Run forever */
    while(true)
    {
        /* I2C sensor readings */

        /* I2C transaction setup */
        i2cTransaction.writeBuf   = gTxPacketConfigurationOPT;
        i2cTransaction.writeCount = 3;
        i2cTransaction.readBuf    = rxBuffer;
        i2cTransaction.readCount  = 2;

        /* Init I2C transfer */
        i2cTransaction.slaveAddress = I2C_TARGET_ADDRESS_OPT3001;
        if (!I2C_transfer(i2c, &i2cTransaction)) {
            /* Could not resolve a sensor, error */
            Display_printf(display, 0, 0, "Error. No OPT sensor found!");
            while(1);
        }

        if (HDC2010_selection_flag == 1)
        {
            i2cTransaction.writeBuf = gTxPacketConfigurationHDC;
            i2cTransaction.slaveAddress = I2C_TARGET_ADDRESS_HDC2010;
            if (!I2C_transfer(i2c, &i2cTransaction)) {
                /* Could not resolve a sensor, error */
                Display_printf(display, 0, 0, "Error. No HDC sensor found!");
                while(1);
            }
        }



        /* AMBIENT LIGHT MEASUREMENT */

        ClockP_sleep(1);

        i2cTransaction.writeBuf = OPT3001_REG;
        i2cTransaction.writeCount = 1;
        i2cTransaction.slaveAddress = I2C_TARGET_ADDRESS_OPT3001;

        /* Take samples and print them out onto the console */
        if (I2C_transfer(i2c, &i2cTransaction)) {
            /*
            * Extract Lux from the received data;
            * see OPT3001 datasheet
            */
            packet[9] = rxBuffer[0];
            packet[10] = rxBuffer[1];
            exponent = (rxBuffer[0] >> 4) & 0x0F;
            value = rxBuffer[0] & 0x0F;
            result  = (value << 8) | rxBuffer[1];
            lightLux = 0.01 * pow(2, exponent) * result;

            Display_printf(display, 0, 0, "Sample: %d lx", lightLux);
        }
        else {
            Display_printf(display, 0, 0, "I2C Bus fault.");
        }
        /* HUMIDITY MEASUREMENT */



        if (HDC2010_selection_flag == 1)
        {
            i2cTransaction.writeBuf = &hdcReg;
            i2cTransaction.slaveAddress = I2C_TARGET_ADDRESS_HDC2010;

            /* Take samples and print them out onto the console */
            if (I2C_transfer(i2c, &i2cTransaction)) {
                /*
                * Extract Lux from the received data;
                * see HDC2010 datasheet
                */
                packet[11] = rxBuffer[0];
                packet[12] = rxBuffer[1];
                hum = (rxBuffer[1] << 8) | rxBuffer[0];
                humRH = HDC2010_humToIntRelative(hum);
                Display_printf(display, 0, 0, "Sample: %d RH", humRH);

            }
            else {
                Display_printf(display, 0, 0, "I2C Bus fault.");
            }

            /* TEMPERATURE MEASUREMENT */

            i2cTransaction.writeBuf = HDC2010_T_REG;

            /* Take samples and print them out onto the console */
            if (I2C_transfer(i2c, &i2cTransaction)) {
                /*
                * Extract Lux from the received data;
                * see HDC2010 datasheet
                */
                packet[13] = rxBuffer[0];
                packet[14] = rxBuffer[1];
                tmp = (rxBuffer[1] << 8) | rxBuffer[0];
                tmpCelsius = HDC2010_tempToFloatCelsius(tmp);
                tmpCelsiusInt = (int)tmpCelsius;
                tmpCelsiusFraction = (int)((tmpCelsius - tmpCelsiusInt) * 10);
                Display_printf(display, 0, 0, "Sample: %d.%d C", tmpCelsiusInt, tmpCelsiusFraction);

            }
            else {
                Display_printf(display, 0, 0, "I2C Bus fault.");
            }
        }

        if (HDC3020_selection_flag == 1)
        {

            uint8_t cmd[2];
            uint8_t rxBuf[6];

            cmd[0] = (HDC3022_CMD_MEASURE >> 8) & 0xFF;
            cmd[1] = HDC3022_CMD_MEASURE & 0xFF;

            i2cTransaction.slaveAddress = HDC3022_I2C_ADDR;
            i2cTransaction.writeBuf     = cmd;
            i2cTransaction.writeCount   = 2;
            i2cTransaction.readBuf      = rxBuf;
            i2cTransaction.readCount    = 6;

            I2C_transfer(i2c, &i2cTransaction);

            ClockP_sleep(1);

            if (I2C_transfer(i2c, &i2cTransaction))
            {
                /* CRC check */
                if (hdc3022_crc8(rxBuf, 2) != rxBuf[2] ||
                    hdc3022_crc8(&rxBuf[3], 2) != rxBuf[5])
                {
                    Display_printf(display, 0, 0, "HDC3022 CRC error!");
                }
                else
                {
                    uint16_t rawTemp = (rxBuf[0] << 8) | rxBuf[1];
                    uint16_t rawHum  = (rxBuf[3] << 8) | rxBuf[4];

                    float tempC = HDC3022_rawToCelsius(rawTemp);
                    uint8_t humRH = HDC3022_rawToRH(rawHum);

                    packet[11] = rxBuf[3];
                    packet[12] = rxBuf[4];
                    packet[13] = rxBuf[0];
                    packet[14] = rxBuf[1];

                    Display_printf(display, 0, 0,
                        "HDC3022: %d.%d C  %d RH",
                        (int)tempC,
                        (int)((tempC - (int)tempC) * 10),
                        humRH);
                }
            }
            else
            {
                Display_printf(display, 0, 0, "HDC3022 I2C error");
            }

        }



        I2C_close(i2c);
        Display_printf(display, 0, 0, "I2C closed!\n");


        /* RADIO */

        // /* Create packet with incrementing sequence number & random payload */
        // packet[0] = (uint8_t)(seqNumber >> 8);
        // packet[1] = (uint8_t)(seqNumber);
        // uint8_t i;
        // for (i = 2; i < PAYLOAD_LENGTH; i++)
        // {
        //     packet[i] = rand();
        // }

        /* Set absolute TX time to utilize automatic power management */
        time += (PACKET_INTERVAL_US * 4);
        RF_cmdNop.startTime = time;

        /* Send packet */
        RF_runCmd(rfHandle, (RF_Op*)&RF_cmdNop, RF_PriorityNormal,
                  &callback, 0);

        RF_cmdNop.status = IDLE;
        RF_cmdPropCs.status = IDLE;
        RF_cmdCountBranch.status = IDLE;
        RF_cmdPropTx.status = IDLE;
        RF_cmdCountBranch.counter = CS_RETRIES_WHEN_BUSY;
    }
}

/*
 *  ======== callback ========
 */
void callback(RF_Handle h, RF_CmdHandle ch, RF_EventMask e)
{
    if ((e & RF_EventLastCmdDone) && (RF_cmdPropTx.status == PROP_DONE_OK))
    {
        seqNumber++;
        PIN_setOutputValue(ledPinHandle, Board_PIN_LED1,
                           !PIN_getOutputValue(Board_PIN_LED1));
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

uint8_t hdc3022_crc8(uint8_t *data, uint8_t len)
{
    uint8_t crc = 0xFF;
    uint8_t i;
    for (i = 0; i < len; i++)
    {
        crc ^= data[i];
        uint8_t b;
        for (b = 0; b < 8; b++)
            crc = (crc & 0x80) ? (crc << 1) ^ 0x31 : (crc << 1);
    }
    return crc;
}

float HDC3022_rawToCelsius(uint16_t raw)
{
    return -45.0f + (175.0f * ((float)raw / 65535.0f));
}

uint8_t HDC3022_rawToRH(uint16_t raw)
{
    return (uint8_t)(100.0f * ((float)raw / 65535.0f));
}


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
