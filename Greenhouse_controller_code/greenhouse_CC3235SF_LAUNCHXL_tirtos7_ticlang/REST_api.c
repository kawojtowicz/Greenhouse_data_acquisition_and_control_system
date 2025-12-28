#include "string.h"
#include "lib/cJSON.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include <ti/net/http/httpclient.h>
//#include <ti/net/tls.h>
#include "semaphore.h"
#include <ti/sysbios/knl/Clock.h>
#include "zoneList.h"
#include <ti/display/Display.h>
#include "zone.h"

//#define HOSTNAME              "http://192.168.0.101/:3000"
//#define HOSTNAME              "http://10.24.190.62:3000"
//#define HOSTNAME              "http://192.168.0.102:3000"
//#define HOSTNAME              "http://192.168.0.101:3000"
#define HOSTNAME              "http://192.168.1.38:3000"
//#define HOSTNAME              "https://greenhouse-data-acquisition-and-control.onrender.com"
//#define HOSTNAME "greenhouse-data-acquisition-and-control.onrender.com"
#define HTTPS_PORT 443

#define USER_AGENT            "HTTPClient (ARM; TI-RTOS)"
#define HTTP_MIN_RECV         (1024)
#define DEVICE_TOKEN          "YOUR_DEVICE_TOKEN_HERE"

//static const char LETS_ENCRYPT_ROOT_CA[] =
//"-----BEGIN CERTIFICATE-----\n"
//"MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw\n"
//"TzELMAkGA1UEBhMCVVMxKTAnBgNVBAoTIEludGVybmV0IFNlY3VyaXR5IFJlc2Vh\n"
//"cmNoIEdyb3VwMRUwEwYDVQQDEwxJU1JHIFJvb3QgWDEwHhcNMTUwNjA0MTEwNDM4\n"
//"WhcNMzUwNjA0MTEwNDM4WjBPMQswCQYDVQQGEwJVUzEpMCcGA1UEChMgSW50ZXJu\n"
//"ZXQgU2VjdXJpdHkgUmVzZWFyY2ggR3JvdXAxFTATBgNVBAMTDElTUkcgUm9vdCBY\n"
//"MTCCAiIwDQYJKoZIhvcNAQEBBQADggIPADCCAgoCggIBAK3oJHP0FDfzm54rVygc\n"
//"... (TRUNCATED FOR BREVITY — keep full cert!)\n"
//"-----END CERTIFICATE-----\n";


extern sem_t ipEventSyncObj;
extern Display_Handle display;
extern Zone zones[30];
extern void printError(char *errString, int code);


//static HTTPClient_Handle createHttpsClient(void)
//{
//    HTTPClient_Params params;
//    HTTPClient_Handle client;
//
//    HTTPClient_Params_init(&params);
//    params.flags = HTTPCLIENT_FLAG_SECURE;
//    params.tlsParams.rootCa = LETS_ENCRYPT_ROOT_CA;
//    params.tlsParams.rootCaLen = strlen(LETS_ENCRYPT_ROOT_CA);
//
//    client = HTTPClient_create(NULL, &params);
//    return client;
//}


/*!
    \brief  Make an HTTP POST logs request to the HTTP server

 */
int httpPostHtlLog(char* requsetURI, float temperature, float humidity, int light, uint64_t id_sensor_node, const char* deviceId, uint8_t nodeType)
{
    char data[HTTP_MIN_RECV];
    int16_t ret = 0;
    int16_t statusCode;
    int serverStatusCode;

    snprintf(data, sizeof(data),
             "{ \"temperature\": %.1f, \"humidity\": %.1f, \"light\": %d, "
                 "\"id_sensor_node\": \"%llu\", \"device_id\": \"%s\", \"node_type\": %u }",
        temperature,
        humidity,
        light,
        (unsigned long long)id_sensor_node,
        deviceId,
        nodeType
    );



    HTTPClient_Handle httpClientHandle = HTTPClient_create(&statusCode, 0);
    if(statusCode < 0) {
//        printError("httpTask: creation of http client handle failed", statusCode);
        return 0;
    }

    ret = HTTPClient_setHeader(httpClientHandle,
                               HTTPClient_HFIELD_REQ_USER_AGENT,
                               USER_AGENT,
                               strlen(USER_AGENT)+1,
                               HTTPClient_HFIELD_PERSISTENT);
    if(ret < 0) {
//        printError("httpTask: setting user-agent failed", ret);
    }

    ret = HTTPClient_setHeader(httpClientHandle,
                               HTTPClient_HFIELD_REQ_CONTENT_TYPE,
                               "application/json",
                               strlen("application/json")+1,
                               HTTPClient_HFIELD_PERSISTENT);
    if(ret < 0) {
//        printError("httpTask: setting content-type failed", ret);
    }

    ret = HTTPClient_connect(httpClientHandle, HOSTNAME, 0, 0);
    if(ret < 0) {
//        printError("httpTask: connect failed", ret);
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
//        printError("httpTask: send failed", ret);
    }

    ret = HTTPClient_disconnect(httpClientHandle);
    if(ret < 0) {
//        printError("httpTask: disconnect failed", ret);
    }

    HTTPClient_destroy(httpClientHandle);
    return serverStatusCode;
}


/*!
    \brief  Sends the device MAC and controller name to the server (POST /devices/announce)
    \param[in] deviceId         The MAC or unique ID of the device
    \param[in] controllerName   Name of the controller
    \return HTTP status code or negative value on error
*/
int httpPostAnnounceDevice(const char* deviceId, const char* controllerName)
{
    char data[HTTP_MIN_RECV];
    int16_t ret = 0;
    int16_t statusCode = 0;

    // Przygotuj JSON
    snprintf(data, sizeof(data),
             "{ \"device_id\": \"%s\", \"controller_name\": \"%s\" }",
             deviceId, controllerName);

    HTTPClient_Handle httpClientHandle = HTTPClient_create(&statusCode, 0);
    if (statusCode < 0) {
//        printError("HTTP client creation failed", statusCode);
        return statusCode;
    }

    // Ustaw nag³ówki
    ret = HTTPClient_setHeader(httpClientHandle,
                               HTTPClient_HFIELD_REQ_USER_AGENT,
                               USER_AGENT,
                               strlen(USER_AGENT) + 1,
                               HTTPClient_HFIELD_PERSISTENT);
    if (ret < 0) {
//        printError("Setting User-Agent failed", ret);
    }

    ret = HTTPClient_setHeader(httpClientHandle,
                               HTTPClient_HFIELD_REQ_CONTENT_TYPE,
                               "application/json",
                               strlen("application/json") + 1,
                               HTTPClient_HFIELD_PERSISTENT);
    if (ret < 0) {
//        printError("Setting Content-Type failed", ret);
    }

    // Po³¹cz z serwerem
    ret = HTTPClient_connect(httpClientHandle, HOSTNAME, 0, 0);
    if (ret < 0) {
//        printError("HTTP connect failed", ret);
        HTTPClient_destroy(httpClientHandle);
        return ret;
    }

    // Wyœlij POST request
    ret = HTTPClient_sendRequest(httpClientHandle,
                                 HTTP_METHOD_POST,
                                 "/devices",
                                 data,
                                 strlen(data),
                                 0);

    if (ret < 0) {
//        printError("HTTP POST send failed", ret);
    }

    // Zapamiêtaj kod statusu HTTP
    statusCode = ret;

    // Od³¹cz i zniszcz klienta
    ret = HTTPClient_disconnect(httpClientHandle);
    if (ret < 0) {
//        printError("HTTP disconnect failed", ret);
    }

    HTTPClient_destroy(httpClientHandle);
    return statusCode;
}

ZoneList httpGetDeviceZones(const char* deviceId)
{
    ZoneList result;
    result.zoneIds = NULL;
    result.count = 2;

    char recvBuffer[HTTP_MIN_RECV];
    int16_t ret = 0;
    int16_t statusCode = 0;
    bool moreDataFlag = false;

    HTTPClient_Handle httpClientHandle = HTTPClient_create(&statusCode, 0);
    if(statusCode < 0) return result;

    // Nag³ówki
    ret = HTTPClient_setHeader(httpClientHandle,
                               HTTPClient_HFIELD_REQ_USER_AGENT,
                               USER_AGENT,
                               strlen(USER_AGENT)+1,
                               HTTPClient_HFIELD_PERSISTENT);

    char authHeader[128];
    snprintf(authHeader, sizeof(authHeader), "Bearer %s", DEVICE_TOKEN);
    HTTPClient_setHeader(httpClientHandle,
                         HTTPClient_HFIELD_REQ_AUTHORIZATION,
                         authHeader,
                         strlen(authHeader)+1,
                         HTTPClient_HFIELD_PERSISTENT);


    ret = HTTPClient_connect(httpClientHandle, HOSTNAME, 0, 0);
    if(ret < 0) {
        HTTPClient_destroy(httpClientHandle);
        return result;
    }

    ret = HTTPClient_sendRequest(httpClientHandle,
                                 HTTP_METHOD_GET,
                                 "/devices/zones",
                                 NULL,
                                 0,
                                 0);
    if(ret < 0) {
        HTTPClient_disconnect(httpClientHandle);
        HTTPClient_destroy(httpClientHandle);
        return result;
    }

    statusCode = ret;
    int totalLen = 0;
    char *fullResponse = malloc(HTTP_MIN_RECV);
    if(!fullResponse) return result;
    memset(fullResponse, 0, HTTP_MIN_RECV);

    do {
        ret = HTTPClient_readResponseBody(httpClientHandle, recvBuffer, sizeof(recvBuffer), &moreDataFlag);
        if(ret < 0) break;

        if(totalLen + ret > HTTP_MIN_RECV) {
            // Realnie lepiej dynamicznie realloc, tu uproszczenie
            ret = HTTP_MIN_RECV - totalLen;
        }
        memcpy(fullResponse + totalLen, recvBuffer, ret);
        totalLen += ret;
    } while(moreDataFlag);

    // Parsowanie JSONs

    cJSON *json = cJSON_Parse(fullResponse);
    if(json) {

        // pobierz pole "zones"
        cJSON *zonesArray = cJSON_GetObjectItem(json, "zones");
        if(zonesArray && cJSON_IsArray(zonesArray)) {

            int arraySize = cJSON_GetArraySize(zonesArray);
            result.zoneIds = malloc(sizeof(int) * arraySize);
            result.count = arraySize;

            for(int i = 0; i < arraySize; i++) {
                cJSON *zone = cJSON_GetArrayItem(zonesArray, i);

                // POPRAWNA nazwa kolumny z bazy
                cJSON *id = cJSON_GetObjectItem(zone, "id_zone");

                if(id && cJSON_IsNumber(id)) {
                    result.zoneIds[i] = id->valueint;
                } else {
                    result.zoneIds[i] = -1;
                }
            }
        }

        cJSON_Delete(json);


    }

    free(fullResponse);
    HTTPClient_disconnect(httpClientHandle);
    HTTPClient_destroy(httpClientHandle);
    return result;
}

void httpGetFullZones(const char* deviceId)
{
    int16_t ret = 0;
    int16_t statusCode = 0;
    bool moreDataFlag = false;

    HTTPClient_Handle httpClientHandle = HTTPClient_create(&statusCode, 0);
    if(statusCode < 0) return;

    // Nag³ówki
    HTTPClient_setHeader(httpClientHandle, HTTPClient_HFIELD_REQ_USER_AGENT,
                         USER_AGENT, strlen(USER_AGENT)+1, HTTPClient_HFIELD_PERSISTENT);

    char authHeader[128];
    snprintf(authHeader, sizeof(authHeader), "Bearer %s", DEVICE_TOKEN);
    HTTPClient_setHeader(httpClientHandle, HTTPClient_HFIELD_REQ_AUTHORIZATION,
                         authHeader, strlen(authHeader)+1, HTTPClient_HFIELD_PERSISTENT);

    ret = HTTPClient_connect(httpClientHandle, HOSTNAME, 0, 0);
    if(ret < 0) {
        HTTPClient_destroy(httpClientHandle);
        return;
    }

    ret = HTTPClient_sendRequest(httpClientHandle,
                                 HTTP_METHOD_GET,
                                 "/devices/zones/full",
                                 NULL, 0, 0);
    if(ret < 0) {
        HTTPClient_disconnect(httpClientHandle);
        HTTPClient_destroy(httpClientHandle);
        return;
    }

    // Bufor na odbiór danych - dynamiczny, roœnie w razie potrzeby
    size_t bufSize = HTTP_MIN_RECV;
    size_t totalLen = 0;
    char *fullResponse = malloc(bufSize);
    if(!fullResponse) {
        HTTPClient_disconnect(httpClientHandle);
        HTTPClient_destroy(httpClientHandle);
        return;
    }

    char recvBuffer[256]; // ma³y bufor na stosie
    do {
        ret = HTTPClient_readResponseBody(httpClientHandle, recvBuffer, sizeof(recvBuffer), &moreDataFlag);
        if(ret < 0) break;

        if(totalLen + ret > bufSize) {
            bufSize *= 2; // podwajamy rozmiar
            char *tmp = realloc(fullResponse, bufSize);
            if(!tmp) {
                free(fullResponse);
                HTTPClient_disconnect(httpClientHandle);
                HTTPClient_destroy(httpClientHandle);
                return;
            }
            fullResponse = tmp;
        }

        memcpy(fullResponse + totalLen, recvBuffer, ret);
        totalLen += ret;
    } while(moreDataFlag);

    // Parsowanie JSON
    cJSON *json = cJSON_ParseWithLength(fullResponse, totalLen);
    free(fullResponse); // zwalniamy bufor od razu

    if(!json) {
        HTTPClient_disconnect(httpClientHandle);
        HTTPClient_destroy(httpClientHandle);
        return;
    }

    cJSON *zonesArray = cJSON_GetObjectItem(json, "zones");
    if(zonesArray && cJSON_IsArray(zonesArray)) {
        int arraySize = cJSON_GetArraySize(zonesArray);
        if(arraySize > 30) arraySize = 30;

        for(int i = 0; i < arraySize; i++) {
            cJSON *zoneJSON = cJSON_GetArrayItem(zonesArray, i);
            zones[i].zoneID = cJSON_GetObjectItem(zoneJSON, "zoneID")->valueint;

            // SensorValues
            cJSON *sensorsJSON = cJSON_GetObjectItem(zoneJSON, "sensorValues");
            if(sensorsJSON) {
                zones[i].sensorValues.sensorNodeID = cJSON_GetObjectItem(sensorsJSON, "sensorNodeID")->valueint;
                zones[i].sensorValues.tmpCelsius   = (float)cJSON_GetObjectItem(sensorsJSON, "tmpCelsius")->valuedouble;
                zones[i].sensorValues.humRH       = (float)cJSON_GetObjectItem(sensorsJSON, "humRH")->valuedouble;
                zones[i].sensorValues.lightLux    = (float)cJSON_GetObjectItem(sensorsJSON, "lightLux")->valuedouble;
            }

            // EndDevices
            const char* types[] = {"tempEndDevices", "humEndDevices", "lightEndDevices"};
            EndDevice *arrays[] = {zones[i].tempEndDevices, zones[i].humEndDevices, zones[i].lightEndDevices};

            for(int t = 0; t < 3; t++) {
                cJSON *devArrayJSON = cJSON_GetObjectItem(zoneJSON, types[t]);
                // reset
                for(int j = 0; j < 30; j++) arrays[t][j] = (EndDevice){0};

                if(devArrayJSON && cJSON_IsArray(devArrayJSON)) {
                    int devCount = cJSON_GetArraySize(devArrayJSON);
                    for(int j = 0; j < devCount && j < 30; j++) {
                        cJSON *ed = cJSON_GetArrayItem(devArrayJSON, j);
                        arrays[t][j].id        = (uint64_t)cJSON_GetObjectItem(ed, "id")->valuedouble;
                        arrays[t][j].upValue   = (float)cJSON_GetObjectItem(ed, "upValue")->valuedouble;
                        arrays[t][j].downValue = (float)cJSON_GetObjectItem(ed, "downValue")->valuedouble;
                        arrays[t][j].onOff     = (uint8_t)cJSON_GetObjectItem(ed, "onOff")->valueint;
                    }
                }
            }
        }
    }

    cJSON_Delete(json);
    HTTPClient_disconnect(httpClientHandle);
    HTTPClient_destroy(httpClientHandle);
}
//#include "string.h"
//#include "lib/cJSON.h"
//#include <stdlib.h>
//#include <stdio.h>
//#include <ti/net/http/httpclient.h>
//#include "zoneList.h"
//#include "zone.h"
//
//#define HOSTNAME            "greenhouse-data-acquisition-and-control.onrender.com"
//#define HTTPS_PORT          443
//#define USER_AGENT          "HTTPClient (ARM; TI-RTOS)"
//#define HTTP_MIN_RECV       (1024)
//#define DEVICE_TOKEN        "YOUR_DEVICE_TOKEN_HERE"
//
//// Root CA
//static const char LETS_ENCRYPT_ROOT_CA[] =
//"-----BEGIN CERTIFICATE-----\n"
//"MIIFazCCA1OgAwIBAgIRAIIQz7DSQONZRGPgu2OCiwAwDQYJKoZIhvcNAQELBQAw\n"
//"... (TRUNCATED — keep full cert!)\n"
//"-----END CERTIFICATE-----\n";
//
//// TLS client setup
//static HTTPClient_Handle createHttpsClient(void)
//{
//    int16_t status;
//    HTTPClient_Handle client = HTTPClient_create(&status, 0);
//    if (status < 0) return NULL;
//    return client;
//}
//
//// POST logs
//int httpPostHtlLog(const char* requestURI,
//                   float temperature,
//                   float humidity,
//                   int light,
//                   uint64_t id_sensor_node,
//                   const char* deviceId,
//                   uint8_t nodeType)
//{
//    HTTPClient_Handle client;
//    HTTPClient_extSecParams secParams;
//    int ret;
//
//    char jsonPayload[512];
////    snprintf(jsonPayload, sizeof(jsonPayload),
////             "{ \"temperature\": %.1f, \"humidity\": %.1f, \"light\": %d, "
////             "\"id_sensor_node\": \%llu\, \"device_id\": \"%s\", \"node_type\": %u }",
////             temperature, humidity, light,
////             (unsigned long long)id_sensor_node,
////             deviceId, nodeType);
//    char idSensorStr[32];  // Enough for 64-bit integer
//    snprintf(idSensorStr, sizeof(idSensorStr), "%llu", (unsigned long long)id_sensor_node);
//
//    snprintf(jsonPayload, sizeof(jsonPayload),
//             "{ \"temperature\": %.1f, \"humidity\": %.1f, \"light\": %d, "
//             "\"id_sensor_node\": \"%s\", \"device_id\": \"%s\", \"node_type\": %u }",
//             temperature,
//             humidity,
//             light,
//             idSensorStr,   // Pass the string version here
//             deviceId,
//             nodeType
//    );
//
//
//    client = createHttpsClient();
//    if (!client) return -1;
//
//    memset(&secParams, 0, sizeof(secParams));
//    secParams.rootCa = LETS_ENCRYPT_ROOT_CA;
//
//    // Connect — port is passed as third argument
//    ret = HTTPClient_connect(client, HOSTNAME, &secParams, 0);
//    if (ret < 0) goto cleanup;
//
//    HTTPClient_setHeader(client, HTTPClient_HFIELD_REQ_USER_AGENT,
//                         USER_AGENT, strlen(USER_AGENT),
//                         HTTPClient_HFIELD_PERSISTENT);
//
//    HTTPClient_setHeader(client, HTTPClient_HFIELD_REQ_CONTENT_TYPE,
//                         "application/json", strlen("application/json"),
//                         HTTPClient_HFIELD_PERSISTENT);
//
//    // Send POST — return value is the HTTP status code
//    ret = HTTPClient_sendRequest(client,
//                                 HTTP_METHOD_POST,
//                                 requestURI,
//                                 jsonPayload,
//                                 strlen(jsonPayload),
//                                 0);
//
//cleanup:
//    HTTPClient_disconnect(client);
//    HTTPClient_destroy(client);
//    return ret;
//}
//
//// POST device announce
//int httpPostAnnounceDevice(const char* deviceId, const char* controllerName)
//{
//    char payload[128];
//    snprintf(payload, sizeof(payload),
//             "{ \"device_id\":\"%s\", \"controller_name\":\"%s\" }",
//             deviceId, controllerName);
//
//    HTTPClient_Handle client = createHttpsClient();
//    if (!client) return -1;
//
//    HTTPClient_extSecParams secParams = {0};
//    secParams.rootCa = LETS_ENCRYPT_ROOT_CA;
//
//    int ret = HTTPClient_connect(client, HOSTNAME, &secParams, 0);
//    if (ret < 0) goto cleanup;
//
//    HTTPClient_setHeader(client, HTTPClient_HFIELD_REQ_USER_AGENT,
//                         USER_AGENT, strlen(USER_AGENT),
//                         HTTPClient_HFIELD_PERSISTENT);
//
//    HTTPClient_setHeader(client, HTTPClient_HFIELD_REQ_CONTENT_TYPE,
//                         "application/json", strlen("application/json"),
//                         HTTPClient_HFIELD_PERSISTENT);
//
//    ret = HTTPClient_sendRequest(client, HTTP_METHOD_POST,
//                                 "/devices", payload, strlen(payload), 0);
//
//cleanup:
//    HTTPClient_disconnect(client);
//    HTTPClient_destroy(client);
//    return ret; // HTTP status code
//}
//
//// GET device zones
//ZoneList httpGetFullZones(void)
//{
//    ZoneList result = { .zoneIds = NULL, .count = 0 };
//    HTTPClient_Handle client;
//    bool moreData;
//    char buffer[HTTP_MIN_RECV];
//
//    client = createHttpsClient();
//    if (!client) return result;
//
//    HTTPClient_extSecParams secParams = {0};
//    secParams.rootCa = LETS_ENCRYPT_ROOT_CA;
//
//    int ret = HTTPClient_connect(client, HOSTNAME, &secParams, 0);
//    if (ret < 0) goto cleanup;
//
//    char auth[128];
//    snprintf(auth, sizeof(auth), "Bearer %s", DEVICE_TOKEN);
//    HTTPClient_setHeader(client, HTTPClient_HFIELD_REQ_AUTHORIZATION,
//                         auth, strlen(auth),
//                         HTTPClient_HFIELD_PERSISTENT);
//
//    ret = HTTPClient_sendRequest(client, HTTP_METHOD_GET,
//                                 "/devices/zones/full", NULL, 0, 0);
//    if (ret < 0) goto cleanup;
//
//    ret = HTTPClient_readResponseBody(client, buffer, sizeof(buffer), &moreData);
//    if (ret <= 0) goto cleanup;
//
//    cJSON *json = cJSON_Parse(buffer);
//    if (!json) goto cleanup;
//
//    cJSON *zones = cJSON_GetObjectItem(json, "zones");
//    int count = cJSON_GetArraySize(zones);
//
//    result.zoneIds = malloc(sizeof(int) * count);
//    result.count = count;
//
//    for (int i = 0; i < count; i++) {
//        cJSON *z = cJSON_GetArrayItem(zones, i);
//        result.zoneIds[i] = cJSON_GetObjectItem(z, "id_zone")->valueint;
//    }
//
//    cJSON_Delete(json);
//
//cleanup:
//    HTTPClient_disconnect(client);
//    HTTPClient_destroy(client);
//    return result;
//}
