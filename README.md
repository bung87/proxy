# proxy

proxy server, replace resources content,modify redirecting location

### config file

proxy.cfg  

<pre>
[public_addrs]
oa.host1.com=public_ip:public_port
# or local for development or domain
nc.host2.com=localhost:8090
[oa.host1.com:80:8080]  
# target host and port  :local port
/static/modules/workflow/new/js/new.js:
# match the path  

# rules leading with spaces  

# original content <kbd>tab</kbd>  new content

    window.top.<kbd>tab</kbd>window.parent.  

[nc.host2.com:80:8090]
/js/app.*.js:
    <public_addrs>
/portal/frame/device_pc/script/compressed/*.js:
    window.top.$<kbd>tab</kbd>if typeof window.top.$ === "function" window.top.$  
</pre>

section format: [target_host:port:local_port]  
replace rule: path support [fnmatch](https://github.com/achesak/nim-fnmatch)  
