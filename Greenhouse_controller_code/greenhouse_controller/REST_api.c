#include "string.h"
#include <ti/net/http/httpclient.h>
#include "semaphore.h"

#define HOSTNAME              "http://192.168.0.101:3000"
#define USER_AGENT            "HTTPClient (ARM; TI-RTOS)"
#define HTTP_MIN_RECV         (128)

extern sem_t ipEventSyncObj;
extern void printError(char *errString, int code);

/*!
    \brief  Make an HTTP POST logs request to the HTTP server

 */
int httpPostHtlLog(char* requsetURI, float temperature, float humidity, int light, int id_sensor_node)
{
    char data[HTTP_MIN_RECV];
    int16_t ret = 0;
    int16_t statusCode;
    int serverStatusCode;

    snprintf(data, sizeof(data),
             "{ \"temperature\": %.1f, \"humidity\": %.1f, \"light\": %d, \"id_sensor_node\": %d }",
             temperature, humidity, light, id_sensor_node);

    HTTPClient_Handle httpClientHandle = HTTPClient_create(&statusCode, 0);
    if(statusCode < 0) {
        printError("httpTask: creation of http client handle failed", statusCode);
        return 0;
    }

    ret = HTTPClient_setHeader(httpClientHandle,
                               HTTPClient_HFIELD_REQ_USER_AGENT,
                               USER_AGENT,
                               strlen(USER_AGENT)+1,
                               HTTPClient_HFIELD_PERSISTENT);
    if(ret < 0) {
        printError("httpTask: setting user-agent failed", ret);
    }

    ret = HTTPClient_setHeader(httpClientHandle,
                               HTTPClient_HFIELD_REQ_CONTENT_TYPE,
                               "application/json",
                               strlen("application/json")+1,
                               HTTPClient_HFIELD_PERSISTENT);
    if(ret < 0) {
        printError("httpTask: setting content-type failed", ret);
    }

    ret = HTTPClient_connect(httpClientHandle, HOSTNAME, 0, 0);
    if(ret < 0) {
        printError("httpTask: connect failed", ret);
        HTTPClient_destroy(httpClientHandle);
        return 0;
    }

    ret = HTTPClient_sendRequest(httpClientHandle,
                                 HTTP_METHOD_POST,
                                 requsetURI,
                                 data,
                                 strlen(data),
                                 0);

    serverStatusCode = ret;


    if(ret < 0) {
        printError("httpTask: send failed", ret);
    }

    ret = HTTPClient_disconnect(httpClientHandle);
    if(ret < 0) {
        printError("httpTask: disconnect failed", ret);
    }

    HTTPClient_destroy(httpClientHandle);
    return serverStatusCode;
}

///*!
//    \brief  Make an HTTP POST logs request to the HTTP server
//
//    \param[in]  client     Instance of an HTTP client.
//
//    \param[in]  method     HTTP method.
//
//    \param[in]  requestURI The path on the server to open.
//
//    \param[in]  body       The body the user wishes to send in in the request,
//                           The body can be chunked or one body buffer.
//
//    \param[in]  bodyLen    Length of the body sent in the request.
//
//    \param[in]  flags      Special flags when the user wishes not to use the
//                           default settings.
//                           - #HTTPClient_CHUNK_START - First request body chunk.
//                           - #HTTPClient_CHUNK_END - Last request body chunk.
//                           - #HTTPClient_DROP_BODY - only keep the status code
//                             and response headers, the response body will be
//                             dropped.
//
//    \note       - If user wishes to use TLS connection then before calling
//                  HTTPClient_sendRequest(), HTTPClient_connect() should be
//                  called.
//                - If disconnection happened prior to HTTPClient_sendRequest(),
//                  HTTPClient_sendRequest() will reconnect internally.
//                - When sending a body in a request, the "Content-length: " and
//                  "Transfer-Encoding: Chunked" headers will be added
//                  automatically.
//
//    \return     Response status code on success or error code on failure.
// */
//
//void* httpGet(char* requsetURI)
//{
//    bool moreDataFlag = false;
//    char data[HTTP_MIN_RECV];
//    int16_t ret = 0;
//    int16_t len = 0;
//
//    HTTPClient_Handle httpClientHandle;
//    int16_t statusCode;
//    httpClientHandle = HTTPClient_create(&statusCode,0);
//    if(statusCode < 0)
//    {
//        printError("httpTask: creation of http client handle failed",
//                   statusCode);
//    }
//
//    ret =
//        HTTPClient_setHeader(httpClientHandle,
//                             HTTPClient_HFIELD_REQ_USER_AGENT,
//                             USER_AGENT,strlen(USER_AGENT)+1,
//                             HTTPClient_HFIELD_PERSISTENT);
//    if(ret < 0)
//    {
//        printError("httpTask: setting request header failed", ret);
//    }
//
//    ret = HTTPClient_connect(httpClientHandle,HOSTNAME,0,0);
//    if(ret < 0)
//    {
//        printError("httpTask: connect failed", ret);
//    } else {
//
////        Display_printf(display, 0, 0,"connect status: %d\n", ret);
//    }
//    ret =
//        HTTPClient_sendRequest(httpClientHandle,HTTP_METHOD_GET,requsetURI,
//                               NULL,0,
//                               0);
//    if(ret < 0)
//    {
//        printError("httpTask: send failed", ret);
//    }
//
//    if(ret != HTTP_SC_OK)
//    {
//        printError("httpTask: cannot get status", ret);
//    }
//
////    Display_printf(display, 0, 0, "HTTP Response Status Code: %d\n", ret);
//
//    len = 0;
//    do
//    {
//        ret = HTTPClient_readResponseBody(httpClientHandle, data, sizeof(data),
//                                          &moreDataFlag);
//        if(ret < 0)
//        {
//            printError("httpTask: response body processing failed", ret);
//        }
////        Display_printf(display, 0, 0, "%.*s \r\n",ret,data);
//        len += ret;
//    }
//    while(moreDataFlag);
//
////    Display_printf(display, 0, 0, "Received %d bytes of payload\n", len);
//
//    ret = HTTPClient_disconnect(httpClientHandle);
//    if(ret < 0)
//    {
//        printError("httpTask: disconnect failed", ret);
//    }
//
//    HTTPClient_destroy(httpClientHandle);
//    return(0);
//}
//
