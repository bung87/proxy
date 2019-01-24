import ./proxy/configparser
import strutils
import os
import asyncnet, asyncdispatch,httpclient
import uri
import ./proxy/asynchttpserver
import fnmatch
import sets
import zip/zlib
export asyncnet, asyncdispatch

type ProxyServer* = object
  targetHost*:string
  targetPort*:int
  localPort*:int
  server*:AsyncHttpServer



proc cb*(req: Request,publicAddrs:PublicAddrs,rulesMap:RulesMap) {.async.} =
  # debugEcho req
  var client = newAsyncHttpClient()
  var cloneUrl = req.url
  cloneUrl.scheme = "http"
  cloneUrl.hostname = req.target.host
  if req.target.port != 80:
    cloneUrl.port = req.target.port.intToStr
  
  let response = await client.request($cloneUrl, httpMethod = req.reqMethod, body = req.body,headers=req.headers)
  var body = ""
  if response.headers.hasKey("Location"):
    var location = response.headers["Location"].toString
    for k,v in publicAddrs:
      location = location.replace(k,v)
      response.headers["Location"] = location
  else:
    body = await response.bodyStream.readAll()
    if response.headers.hasKey("content-encoding"):
      body = uncompress(body)
    var matchedRules = initOrderedSet[string]()
    for pattern,rules in rulesMap:
      if fnmatch(req.url.path, pattern):
        for p in rules:
          discard matchedRules.containsOrIncl p
    debugEcho $cloneUrl
    debugEcho matchedRules
    if response.headers.hasKey("Content-Length"):
      response.headers.del("Content-Length")
    var arr:seq[string]
    for rule in matchedRules:
      if rule == "<public_addrs>":
          for k,v in publicAddrs:
              body = body.replace(k,v)
      else:
          arr = rule.split('\t')
          if len(arr) == 1:
              continue
          debugEcho("$#\n" % [arr.join("->")])
          body = body.replace(arr[0],arr[1])
    if response.headers.hasKey("content-encoding"):
      body = compress(body)
  await req.respond(response.code,body,response.headers)

proc initProxyServer*(targetHost:string,targetPort:int,localPort:int) : ProxyServer =
  let target = Target(host:targetHost,port:targetPort)
  result.server = newAsyncHttpServer(target)
  
      
proc serve(filepath:string){.async.} =
  var config = initConfigParser()
  config.read(filepath)
  
  var rules:seq[string]
  
  var cachedSections = initOrderedTable[string,OrderedTable[string,seq[string]]]()
  var striped:string
  var publicAddrs:OrderedTable[string,string]
  var rulesMap = initOrderedTable[string,seq[string]]()
  for section in config.sections():
    if section == "public_addrs":
        publicAddrs = config.items(section)
        continue
    rulesMap.clear
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
    proxy.server.publicAddrs = publicAddrs
    proxy.server.rulesMap = rulesMap
    asyncCheck proxy.server.serve(Port(localPort),cb)
    
  debugEcho "############"
  debugEcho cachedSections

when isMainModule:
  asyncCheck serve(paramStr(1).string)
  runForever()