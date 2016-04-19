var http = require('http'),
    httpProxy = require('http-proxy');

//
// Create a proxy server with custom application logic
//
var proxy = httpProxy.createProxyServer({});

//
// Create your custom server and just call `proxy.web()` to proxy
// a web request to the target passed in the options
// also you can use `proxy.ws()` to proxy a websockets request
//
var server = http.createServer(function(req, res) {
  // You can define here your custom logic to handle the request
  // and then proxy the request.
  var path = '/somepath';
  fs.exists(path, function(exists) {
      if(exists) {
          console.log('is file');
          fs.createReadStream(path).pipe(res);
      } else {
          console.log('proxying');
          // Here I need to find a way to write into path
          proxy.web(req, res, {target: 'http://localhost:9000'});
      }
  });
});

console.log("listening on port 5050");
server.listen(5050);
