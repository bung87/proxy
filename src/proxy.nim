import ./proxy/configparser
import strutils
import os
import asyncnet, asyncdispatch
import uri
import fnmatch
import sets
import zip/zlib

include httpclient
include ./proxy/asynchttpserver

export asyncnet, asyncdispatch

type ProxyServer* = object
  targetHost*:string
  targetPort*:int
  localPort*:int
  server*:AsyncHttpServer

proc cb*(req: Request,server: AsyncHttpServer) {.async.} =
  var cloneUrl = req.url
  cloneUrl.scheme = "http"
  cloneUrl.hostname = req.target.host
  var agent = newAsyncHttpClient()
  if req.target.port != 80:
    cloneUrl.port = req.target.port.intToStr
  var response:AsyncResponse
  try:
    response = await agent.request($cloneUrl, httpMethod = req.reqMethod, body = req.body,headers=req.headers)
  except:
    await req.respondError(Http500)
    return
  var body = ""
  if response.headers.hasKey("Location"):
    var location = response.headers["Location"].toString
    for k,v in server.publicAddrs:
      location = location.replace(k,v)
      response.headers["Location"] = location
    agent.close
  else:
    var matchedRules = initOrderedSet[string]()
    for pattern,rules in server.rulesMap:
      if fnmatch(req.url.path, pattern):
        for p in rules:
          discard matchedRules.containsOrIncl p
    debugEcho $cloneUrl
    debugEcho matchedRules
    # @TODO streaming response,or redirect static file request to target server 
    if response.headers["Content-Type"].find("image") != -1:
      var msg = "HTTP/1.1 " & $response.code & "\c\L"
      msg.addHeaders(response.headers)
      msg.add "\c\L\c\L"
      var reqs = newSeq[Future[void]]()
      reqs.add req.client.send(msg)
      let timeout = sleepAsync(1 * 1_000)
      
      while true:
        let (hasData,data) = waitfor response.bodyStream.read
        if hasData == false:
          break
        reqs.add req.client.send(data)
      let a = all(reqs)
      a.addCallback proc() = agent.close
      await a
     
    if response.headers.hasKey("Content-Length"):
      response.headers.del("Content-Length")
    if response.headers.hasKey("transfer-encoding"):
      response.headers.del("transfer-encoding")

    body = await response.bodyStream.readAll()
    agent.close
    var encoding:ZStreamHeader
    if len(matchedRules) > 0 and response.headers.hasKey("content-encoding"):
      debugEcho response.headers["content-encoding"].toString
      case response.headers["content-encoding"].toString:
        of "gzip":
          encoding = ZStreamHeader.GZIP_STREAM
        of "deflate":
          encoding = ZStreamHeader.RAW_DEFLATE
        of "compress":
          encoding = ZStreamHeader.ZLIB_STREAM
      body = uncompress(body,stream = encoding)
    var arr:seq[string]
    for rule in matchedRules:
      if rule == "<public_addrs>":
          for k,v in server.publicAddrs:
              body = body.replace(k,v)
      else:
          arr = rule.split('\t')
          if len(arr) == 1:
              continue
          debugEcho("$#\n" % [arr.join("->")])
          body = body.replace(arr[0],arr[1])
    if len(matchedRules) > 0 and response.headers.hasKey("content-encoding"):
      body = compress(body,stream = encoding)
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
  var publicAddrs = initOrderedTable[string,string]()
  var rulesMap = initOrderedTable[string,seq[string]]()
  for section in config.sections():
    if section == "public_addrs":
      for k,v in config.items(section):
        if k.find(':') == -1:
          publicAddrs.add("$#:80" % [k],v)
          publicAddrs.add(k,v)
        else:
          publicAddrs.add(k,v)
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