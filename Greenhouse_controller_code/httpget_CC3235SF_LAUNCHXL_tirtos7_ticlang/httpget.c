///*
// * Copyright (c) 2015-2017, Texas Instruments Incorporated
// * All rights reserved.
// *
// * Redistribution and use in source and binary forms, with or without
// * modification, are permitted provided that the following conditions
// * are met:
// *
// * *  Redistributions of source code must retain the above copyright
// *    notice, this list of conditions and the following disclaimer.
// *
// * *  Redistributions in binary form must reproduce the above copyright
// *    notice, this list of conditions and the following disclaimer in the
// *    documentation and/or other materials provided with the distribution.
// *
// * *  Neither the name of Texas Instruments Incorporated nor the names of
// *    its contributors may be used to endorse or promote products derived
// *    from this software without specific prior written permission.
// *
// * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// * THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// * PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR
// * CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
// * EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
// * PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS;
// * OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY,
// * WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR
// * OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE,
// * EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
// */
//
///*
// *  ======== httpget.c ========
// *  HTTP Client GET example application
// */
//
///* BSD support */
#include "string.h"
#include <ti/display/Display.h>
#include <ti/net/http/httpclient.h>
#include "semaphore.h"
#include <ti/drivers/net/wifi/simplelink.h>

//#define HOSTNAME              "greenhousedataacquisitionandcontrolsystem-production.up.railway.app"
//#define HOSTNAME              "httpbin.org"
//#define HOSTNAME2              "greenhouse-data-acquisition-and-control.onrender.com\r\n"
#define HOSTNAME              "backend-floral-fog-9850.fly.dev"
//#define HOSTNAME              "greenhouse-data-acquisition-and-control.onrender.com"
//https://greenhouse-data-acquisition-and-control.onrender.com/


//#define REQUEST_URI           "/v1/projects"
#define REQUEST_URI           "/"
#define USER_AGENT            "HTTPClient (ARM; TI-RTOS)"
#define HTTP_MIN_RECV         (256)

extern Display_Handle display;
extern sem_t ipEventSyncObj;
extern void printError(char *errString,
                       int code);


void* httpTask(void* pvParameters)
{
bool moreDataFlag = false;
char data[256];
int16_t ret = 0;
int16_t len = 0;
int status;

Display_printf(display, 0, 0, "Sending a HTTPS GET request to '%s'\n",
HOSTNAME);

HTTPClient_Handle httpClientHandle;
int16_t statusCode;

HTTPClient_extSecParams httpClientSecParams;
memset(&httpClientSecParams, 0, sizeof(HTTPClient_extSecParams));

//httpClientSecParams.rootCa = "www.ti.com.cn.der";
httpClientSecParams.rootCa = "isrgrootx1.der";
//httpClientSecParams.rootCa = "/baltimore.der";

httpClientSecParams.clientCert = NULL;
httpClientSecParams.privateKey = NULL;

int32_t fh;
SlFsFileInfo_t info;

fh = sl_FsGetInfo("isrgrootx1.der", 0, &info);
if (fh < 0) {
    Display_printf(display, 0, 0,
        "CA file NOT FOUND, err=%ld\n", fh);
} else {
    Display_printf(display, 0, 0,
        "CA file OK, size=%ld\n", info.Len);
}



httpClientHandle = HTTPClient_create(&statusCode,0);
if (statusCode < 0)
{
printError("httpTask: creation of http client handle failed", ret);
}


//ret = HTTPClient_setHeader(httpClientHandle, HTTPClient_HFIELD_REQ_USER_AGENT,USER_AGENT,strlen(USER_AGENT),HTTPClient_HFIELD_PERSISTENT);
ret = HTTPClient_setHeader(httpClientHandle, HTTPClient_HFIELD_REQ_USER_AGENT,USER_AGENT,strlen(USER_AGENT),0);
if (ret < 0) {
printError("httpTask: setting request header failed", ret);
}

// ... po sl_Start i upewnieniu siê, ¿e mode == ROLE_STA ...


            SlDateTime_t dateTime = {0};
                dateTime.tm_day = (_u32)15;
                dateTime.tm_mon = (_u32)1;
                dateTime.tm_year = (_u32)2026;
                dateTime.tm_hour = (_u32)10;
                sl_DeviceSet(SL_DEVICE_GENERAL, SL_DEVICE_GENERAL_DATE_TIME, sizeof(SlDateTime_t), (_u8 *)(&dateTime));

            // Ustawienie User-Agent
//            HTTPClient_setHeader(httpClientHandle, HTTPClient_HFIELD_REQ_USER_AGENT, USER_AGENT, strlen(USER_AGENT), 0);

            // Kluczowe dla Render.com - rêczne wymuszenie nag³ówka Host
//            HTTPClient_setHeader(httpClientHandle, HTTPClient_HFIELD_REQ_HOST, HOSTNAME, strlen(HOSTNAME), 0);



            HTTPClient_setHeader(httpClientHandle,
                HTTPClient_HFIELD_REQ_HOST,
                HOSTNAME,
                strlen(HOSTNAME),
                0);  // 0 -> ustawienie nag³ówka na czas TLS handshake

            HTTPClient_setHeader(
                httpClientHandle,
                HTTPClient_HFIELD_REQ_CONNECTION,
                "keep-alive",
                strlen("keep-alive"),
                0
            );


            HTTPClient_setHeader(httpClientHandle,
                HTTPClient_HFIELD_REQ_ACCEPT,
                "*/*",
                3,
                0);




ret = HTTPClient_connect(httpClientHandle, HOSTNAME, &httpClientSecParams, 0);
if (ret < 0) {
printError("httpTask: connect failed", ret);
}


ret = HTTPClient_sendRequest(httpClientHandle,HTTP_METHOD_GET,REQUEST_URI,NULL,0,0);
if (ret < 0) {
printError("httpTask: send failed", ret);
}

//if (ret != HTTP_SC_OK) {
//printError("httpTask: cannot get status", ret);
//}

Display_printf(display, 0, 0, "HTTP Response Status Code: %d\n", ret);

len = 0;
do {
ret = HTTPClient_readResponseBody(httpClientHandle, data, sizeof(data), &moreDataFlag);
if (ret < 0) {
printError("httpTask: response body processing failed", ret);
}
Display_printf(display, 0, 0, "%.*s \r\n",ret ,data);
len += ret;
}while (moreDataFlag);

Display_printf(display, 0, 0, "Received %d bytes of payload\n", len);

ret = HTTPClient_disconnect(httpClientHandle);
if (ret < 0)
{
printError("httpTask: disconnect failed", ret);
}

HTTPClient_destroy(httpClientHandle);
return(0);
}
