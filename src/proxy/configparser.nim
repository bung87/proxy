
# ~/Nim/bin/nim c -r -o:a  src/proxy/configparser.nim ./2proxy.cfg 
import os,streams,strscans,strutils,tables,sequtils
import unicode except strip
export tables

type 
    ConfigParser* = object
        data:OrderedTableRef[string,OrderedTableRef[string,string]]
        optionxform*:proc (x:string) : string
    LineType = enum
        Section,Option,Value

proc initConfigParser*():ConfigParser =
    result.optionxform = toLower


proc read*(self:var ConfigParser,path:string) =
    var fs = newFileStream(path, fmRead)
    var rawline,line:string
    var value,section:string
    var isOption = false
    var lastSection,lastOption = ""
    var lineType:LineType
    self.data = newOrderedTable[string,OrderedTableRef[string,string]]()
    if not isNil(fs):
        while fs.readLine(rawline):
            line = rawline
            if scanf(line, "$s[$*]", section):
                isOption = false
                lineType = LineType.Section
                lastSection = section
                discard self.data.hasKeyOrPut(lastSection,newOrderedTable[string,string]())
                debugEcho "section",section
            elif  scanf(line, "$s$*=$.", section,value) and not isOption:
                isOption = true
                lineType = LineType.Option
                lastOption = section
                debugEcho "option",section,value
            elif  scanf(line, "$s$*:$.", section,value) and not isOption:
                isOption = true
                lastOption = section
                lineType = LineType.Option
                debugEcho "option",section,value
            else:
                if len(line) == 0:
                    continue
                elif line.strip().startswith('#'):
                    continue
                elif line.strip().startswith(';'):
                    continue
                var ret = line.split({':','='},maxsplit=1)
                if lineType != LineType.Option:
                    
                    if len(ret) == 2:
                        lastOption = self.optionxform(ret[0])
                        self.data[lastSection][lastOption] = ret[1]
                    else:
                       if line.startsWith(' '):
                        self.data[lastSection][lastOption].add "\n$#" % ret
                       else:
                        self.data[lastSection][self.optionxform(ret[0])] = ""
                else:
                    if self.data[lastSection].hasKeyOrPut(lastOption,line):
                        self.data[lastSection][lastOption].add "\n$#" % [line]
                isOption = false
    debugEcho self.data
    fs.close()

proc sections*(self:ConfigParser):seq[string] = 
    result = toSeq(self.data.keys)

proc items*(self:ConfigParser,section:string):OrderedTable[string,string] = 
    result = self.data[section][]

proc getlist*(self:ConfigParser,section,option:string):seq[string] = 
    result = splitLines(self.data[section][option])

when isMainModule:
    var parser = initConfigParser()
    # parser.optionxform = toLower
    parser.read(paramStr(1).string)
    debugEcho parser.sections