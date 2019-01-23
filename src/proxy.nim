import ./proxy/configparser
import strutils
import os
import asyncnet, asyncdispatch,httpclient
import uri
import ./proxy/asynchttpserver

export asyncnet, asyncdispatch

type ProxyServer* = object
  targetHost*:string
  targetPort*:int
  localPort*:int
  server*:AsyncHttpServer

proc cb*(req: Request) {.async.} =
  debugEcho req
  var client = newAsyncHttpClient()
  var cloneUrl = req.url
  cloneUrl.scheme = "http"
  cloneUrl.hostname = req.target.host
  cloneUrl.port = req.target.port.intToStr
  debugEcho $cloneUrl
  let response = await client.request($cloneUrl, httpMethod = req.reqMethod, body = req.body)
  let body = await response.bodyStream.readAll()
  await req.respond(response.code,body,response.headers)

proc initProxyServer*(targetHost:string,targetPort:int,localPort:int) : ProxyServer =
  let target = Target(host:targetHost,port:targetPort)
  result.server = newAsyncHttpServer(target)
  asyncCheck result.server.serve(Port(localPort),cb)
      
proc serve(filepath:string){.async.} =
  var config = initConfigParser()
  config.read(filepath)
  var public_addrs:OrderedTable[string,string]
  var rules:seq[string]
  var rulesMap = initOrderedTable[string,seq[string]]()
  var cachedSections = initOrderedTable[string,OrderedTable[string,seq[string]]]()
  var striped:string
  for section in config.sections():
    if section == "public_addrs":
        public_addrs = config.items(section)
        continue
    for p, _ in config.items(section):
        rules = config.getlist(section,p)
        for r in rules:
          striped = r.strip()
          if rulesMap.hasKeyOrPut(p,@[striped]):
            rulesMap[p].add(striped)
    cachedSections[section] = rulesMap
    var arr = section.split(":")
    var 
      host = arr[0]
      port = parseInt(arr[1])
      local_port = parseInt(arr[2])
    let proxy = initProxyServer(host,port,local_port)
    
  debugEcho "############"
  debugEcho cachedSections

when isMainModule:
  asyncCheck serve(paramStr(1).string)
  runForever()